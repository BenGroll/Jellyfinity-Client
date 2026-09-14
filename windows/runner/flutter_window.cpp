#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include <endpointvolume.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "ole32.lib")

namespace {

using Microsoft::WRL::ComPtr;

// The default audio render endpoint's master volume, as a 0.0-1.0 scalar,
// or nullopt when no endpoint could be reached (no audio device present,
// COM not initialized on this thread, or similar) — the "must say so"
// half of RemoteCommandKind.setVolume's PlaybackEngine.systemVolume
// contract. COM itself is already initialized once in main.cpp.
std::optional<float> GetSystemVolume() {
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                               CLSCTX_ALL, IID_PPV_ARGS(&enumerator)))) {
    return std::nullopt;
  }
  ComPtr<IMMDevice> device;
  if (FAILED(
          enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device))) {
    return std::nullopt;
  }
  ComPtr<IAudioEndpointVolume> endpoint_volume;
  if (FAILED(device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                               nullptr,
                               reinterpret_cast<void**>(
                                   endpoint_volume.GetAddressOf())))) {
    return std::nullopt;
  }
  float level = 0.0f;
  if (FAILED(endpoint_volume->GetMasterVolumeLevelScalar(&level))) {
    return std::nullopt;
  }
  return level;
}

bool SetSystemVolume(float level) {
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                               CLSCTX_ALL, IID_PPV_ARGS(&enumerator)))) {
    return false;
  }
  ComPtr<IMMDevice> device;
  if (FAILED(
          enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device))) {
    return false;
  }
  ComPtr<IAudioEndpointVolume> endpoint_volume;
  if (FAILED(device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                               nullptr,
                               reinterpret_cast<void**>(
                                   endpoint_volume.GetAddressOf())))) {
    return false;
  }
  return SUCCEEDED(
      endpoint_volume->SetMasterVolumeLevelScalar(level, nullptr));
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  storage_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "jellyfinity/storage",
          &flutter::StandardMethodCodec::GetInstance());
  storage_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() != "availableBytes") {
          result->NotImplemented();
          return;
        }
        const auto* path = call.arguments()
            ? std::get_if<std::string>(call.arguments()) : nullptr;
        if (!path || path->empty()) {
          result->Error("invalid_path", "A directory is required.");
          return;
        }
        const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
            path->data(), static_cast<int>(path->size()), nullptr, 0);
        if (length == 0) {
          result->Error("invalid_path", "Invalid directory encoding.");
          return;
        }
        std::wstring wide_path(length, L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->data(),
            static_cast<int>(path->size()), wide_path.data(), length);
        ULARGE_INTEGER available;
        if (!GetDiskFreeSpaceExW(wide_path.c_str(), &available, nullptr, nullptr)) {
          result->Error("storage_unavailable", "Cannot read free disk space.");
          return;
        }
        result->Success(flutter::EncodableValue(
            static_cast<int64_t>(available.QuadPart)));
      });
  // Same channel name and method vocabulary as the Android side
  // (MainActivity.kt) so JustAudioPlaybackEngine's Dart code needs no
  // per-platform branching beyond "is this a platform with a bridge at
  // all" (v0.6.0 — RemoteCommandKind.setVolume's real execution path).
  device_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "io.nachbar.jellyfinity/device",
          &flutter::StandardMethodCodec::GetInstance());
  device_channel_->SetMethodCallHandler(
      [](const auto& call, auto result) {
        if (call.method_name() == "getSystemVolume") {
          auto volume = GetSystemVolume();
          if (!volume) {
            result->Success(flutter::EncodableValue());
            return;
          }
          result->Success(
              flutter::EncodableValue(static_cast<double>(*volume)));
        } else if (call.method_name() == "setSystemVolume") {
          const auto* value = call.arguments()
              ? std::get_if<double>(call.arguments())
              : nullptr;
          if (!value) {
            result->Error("invalid_volume",
                           "A numeric volume between 0.0 and 1.0 is "
                           "required.");
            return;
          }
          SetSystemVolume(static_cast<float>(*value));
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  storage_channel_ = nullptr;
  device_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
