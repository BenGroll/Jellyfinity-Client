// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'AppDatabase.dart';

// ignore_for_file: type=lint
class $SavedServersTable extends SavedServers
    with TableInfo<$SavedServersTable, SavedServerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reportedVersionMeta = const VerificationMeta(
    'reportedVersion',
  );
  @override
  late final GeneratedColumn<String> reportedVersion = GeneratedColumn<String>(
    'reported_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    baseUrl,
    name,
    reportedVersion,
    serverId,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedServerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('reported_version')) {
      context.handle(
        _reportedVersionMeta,
        reportedVersion.isAcceptableOrUnknown(
          data['reported_version']!,
          _reportedVersionMeta,
        ),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedServerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedServerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      reportedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reported_version'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $SavedServersTable createAlias(String alias) {
    return $SavedServersTable(attachedDatabase, alias);
  }
}

class SavedServerRow extends DataClass implements Insertable<SavedServerRow> {
  /// Jellyfinity's local id for the server (a UUID string).
  final String id;

  /// The normalized base URL, as produced by `JellyfinServerUrl`.
  final String baseUrl;

  /// Display name.
  final String name;

  /// The Jellyfin version string seen at connection time.
  final String reportedVersion;

  /// The server's self-reported Jellyfin id, if it gave one.
  final String? serverId;

  /// Monotonic insertion marker (microseconds since epoch at save time),
  /// so `all()` can return rows in the order they were first saved.
  final int addedAt;
  const SavedServerRow({
    required this.id,
    required this.baseUrl,
    required this.name,
    required this.reportedVersion,
    this.serverId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['base_url'] = Variable<String>(baseUrl);
    map['name'] = Variable<String>(name);
    map['reported_version'] = Variable<String>(reportedVersion);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  SavedServersCompanion toCompanion(bool nullToAbsent) {
    return SavedServersCompanion(
      id: Value(id),
      baseUrl: Value(baseUrl),
      name: Value(name),
      reportedVersion: Value(reportedVersion),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      addedAt: Value(addedAt),
    );
  }

  factory SavedServerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedServerRow(
      id: serializer.fromJson<String>(json['id']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      name: serializer.fromJson<String>(json['name']),
      reportedVersion: serializer.fromJson<String>(json['reportedVersion']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'name': serializer.toJson<String>(name),
      'reportedVersion': serializer.toJson<String>(reportedVersion),
      'serverId': serializer.toJson<String?>(serverId),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  SavedServerRow copyWith({
    String? id,
    String? baseUrl,
    String? name,
    String? reportedVersion,
    Value<String?> serverId = const Value.absent(),
    int? addedAt,
  }) => SavedServerRow(
    id: id ?? this.id,
    baseUrl: baseUrl ?? this.baseUrl,
    name: name ?? this.name,
    reportedVersion: reportedVersion ?? this.reportedVersion,
    serverId: serverId.present ? serverId.value : this.serverId,
    addedAt: addedAt ?? this.addedAt,
  );
  SavedServerRow copyWithCompanion(SavedServersCompanion data) {
    return SavedServerRow(
      id: data.id.present ? data.id.value : this.id,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      name: data.name.present ? data.name.value : this.name,
      reportedVersion: data.reportedVersion.present
          ? data.reportedVersion.value
          : this.reportedVersion,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedServerRow(')
          ..write('id: $id, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('name: $name, ')
          ..write('reportedVersion: $reportedVersion, ')
          ..write('serverId: $serverId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, baseUrl, name, reportedVersion, serverId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedServerRow &&
          other.id == this.id &&
          other.baseUrl == this.baseUrl &&
          other.name == this.name &&
          other.reportedVersion == this.reportedVersion &&
          other.serverId == this.serverId &&
          other.addedAt == this.addedAt);
}

class SavedServersCompanion extends UpdateCompanion<SavedServerRow> {
  final Value<String> id;
  final Value<String> baseUrl;
  final Value<String> name;
  final Value<String> reportedVersion;
  final Value<String?> serverId;
  final Value<int> addedAt;
  final Value<int> rowid;
  const SavedServersCompanion({
    this.id = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.name = const Value.absent(),
    this.reportedVersion = const Value.absent(),
    this.serverId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedServersCompanion.insert({
    required String id,
    required String baseUrl,
    required String name,
    this.reportedVersion = const Value.absent(),
    this.serverId = const Value.absent(),
    required int addedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       baseUrl = Value(baseUrl),
       name = Value(name),
       addedAt = Value(addedAt);
  static Insertable<SavedServerRow> custom({
    Expression<String>? id,
    Expression<String>? baseUrl,
    Expression<String>? name,
    Expression<String>? reportedVersion,
    Expression<String>? serverId,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (baseUrl != null) 'base_url': baseUrl,
      if (name != null) 'name': name,
      if (reportedVersion != null) 'reported_version': reportedVersion,
      if (serverId != null) 'server_id': serverId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedServersCompanion copyWith({
    Value<String>? id,
    Value<String>? baseUrl,
    Value<String>? name,
    Value<String>? reportedVersion,
    Value<String?>? serverId,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return SavedServersCompanion(
      id: id ?? this.id,
      baseUrl: baseUrl ?? this.baseUrl,
      name: name ?? this.name,
      reportedVersion: reportedVersion ?? this.reportedVersion,
      serverId: serverId ?? this.serverId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (reportedVersion.present) {
      map['reported_version'] = Variable<String>(reportedVersion.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedServersCompanion(')
          ..write('id: $id, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('name: $name, ')
          ..write('reportedVersion: $reportedVersion, ')
          ..write('serverId: $serverId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedAccountsTable extends SavedAccounts
    with TableInfo<$SavedAccountsTable, SavedAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    userId,
    username,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedAccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $SavedAccountsTable createAlias(String alias) {
    return $SavedAccountsTable(attachedDatabase, alias);
  }
}

class SavedAccountRow extends DataClass implements Insertable<SavedAccountRow> {
  /// Jellyfinity's local id for the profile (a UUID string). Also the
  /// credential-store key for this account's token.
  final String id;

  /// The local id of the `SavedServers` row this profile belongs to.
  ///
  /// Not a database foreign key: `AuthSessionManager` already orchestrates
  /// cascading removal (it also has to delete the token from secure
  /// storage, which the database cannot see), and a DB-level cascade would
  /// only duplicate that. Indexed for `forServer` lookups.
  final String serverId;

  /// The Jellyfin user's id on that server.
  final String userId;

  /// The Jellyfin username, shown in the account switcher.
  final String username;

  /// Monotonic insertion marker; see [SavedServers.addedAt].
  final int addedAt;
  const SavedAccountRow({
    required this.id,
    required this.serverId,
    required this.userId,
    required this.username,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['server_id'] = Variable<String>(serverId);
    map['user_id'] = Variable<String>(userId);
    map['username'] = Variable<String>(username);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  SavedAccountsCompanion toCompanion(bool nullToAbsent) {
    return SavedAccountsCompanion(
      id: Value(id),
      serverId: Value(serverId),
      userId: Value(userId),
      username: Value(username),
      addedAt: Value(addedAt),
    );
  }

  factory SavedAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedAccountRow(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      username: serializer.fromJson<String>(json['username']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String>(serverId),
      'userId': serializer.toJson<String>(userId),
      'username': serializer.toJson<String>(username),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  SavedAccountRow copyWith({
    String? id,
    String? serverId,
    String? userId,
    String? username,
    int? addedAt,
  }) => SavedAccountRow(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    userId: userId ?? this.userId,
    username: username ?? this.username,
    addedAt: addedAt ?? this.addedAt,
  );
  SavedAccountRow copyWithCompanion(SavedAccountsCompanion data) {
    return SavedAccountRow(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      username: data.username.present ? data.username.value : this.username,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedAccountRow(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, serverId, userId, username, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedAccountRow &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.username == this.username &&
          other.addedAt == this.addedAt);
}

class SavedAccountsCompanion extends UpdateCompanion<SavedAccountRow> {
  final Value<String> id;
  final Value<String> serverId;
  final Value<String> userId;
  final Value<String> username;
  final Value<int> addedAt;
  final Value<int> rowid;
  const SavedAccountsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedAccountsCompanion.insert({
    required String id,
    required String serverId,
    required String userId,
    required String username,
    required int addedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serverId = Value(serverId),
       userId = Value(userId),
       username = Value(username),
       addedAt = Value(addedAt);
  static Insertable<SavedAccountRow> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? username,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedAccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? serverId,
    Value<String>? userId,
    Value<String>? username,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return SavedAccountsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedAccountsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValueEntriesTable extends KeyValueEntries
    with TableInfo<$KeyValueEntriesTable, KeyValueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_value_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $KeyValueEntriesTable createAlias(String alias) {
    return $KeyValueEntriesTable(attachedDatabase, alias);
  }
}

class KeyValueRow extends DataClass implements Insertable<KeyValueRow> {
  final String key;

  /// The value, always stored as text. Typed accessors on `KeyValueStore`
  /// encode/decode bools, ints and doubles.
  final String value;

  /// When this entry was last written (milliseconds since epoch).
  final int updatedAt;
  const KeyValueRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  KeyValueEntriesCompanion toCompanion(bool nullToAbsent) {
    return KeyValueEntriesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory KeyValueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  KeyValueRow copyWith({String? key, String? value, int? updatedAt}) =>
      KeyValueRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  KeyValueRow copyWithCompanion(KeyValueEntriesCompanion data) {
    return KeyValueRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class KeyValueEntriesCompanion extends UpdateCompanion<KeyValueRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const KeyValueEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValueEntriesCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<KeyValueRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValueEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return KeyValueEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedMediaItemsTable extends CachedMediaItems
    with TableInfo<$CachedMediaItemsTable, CachedMediaItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedMediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageItemIdMeta = const VerificationMeta(
    'imageItemId',
  );
  @override
  late final GeneratedColumn<String> imageItemId = GeneratedColumn<String>(
    'image_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageKindMeta = const VerificationMeta(
    'imageKind',
  );
  @override
  late final GeneratedColumn<String> imageKind = GeneratedColumn<String>(
    'image_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAspectRatioMeta = const VerificationMeta(
    'imageAspectRatio',
  );
  @override
  late final GeneratedColumn<double> imageAspectRatio = GeneratedColumn<double>(
    'image_aspect_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistsJsonMeta = const VerificationMeta(
    'artistsJson',
  );
  @override
  late final GeneratedColumn<String> artistsJson = GeneratedColumn<String>(
    'artists_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumItemIdMeta = const VerificationMeta(
    'albumItemId',
  );
  @override
  late final GeneratedColumn<String> albumItemId = GeneratedColumn<String>(
    'album_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMicrosMeta = const VerificationMeta(
    'durationMicros',
  );
  @override
  late final GeneratedColumn<int> durationMicros = GeneratedColumn<int>(
    'duration_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productionYearMeta = const VerificationMeta(
    'productionYear',
  );
  @override
  late final GeneratedColumn<int> productionYear = GeneratedColumn<int>(
    'production_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _childCountMeta = const VerificationMeta(
    'childCount',
  );
  @override
  late final GeneratedColumn<int> childCount = GeneratedColumn<int>(
    'child_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    itemId,
    kind,
    name,
    availability,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    artistsJson,
    albumItemId,
    albumName,
    trackNumber,
    discNumber,
    durationMicros,
    productionYear,
    childCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedMediaItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_availabilityMeta);
    }
    if (data.containsKey('image_item_id')) {
      context.handle(
        _imageItemIdMeta,
        imageItemId.isAcceptableOrUnknown(
          data['image_item_id']!,
          _imageItemIdMeta,
        ),
      );
    }
    if (data.containsKey('image_kind')) {
      context.handle(
        _imageKindMeta,
        imageKind.isAcceptableOrUnknown(data['image_kind']!, _imageKindMeta),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    }
    if (data.containsKey('image_aspect_ratio')) {
      context.handle(
        _imageAspectRatioMeta,
        imageAspectRatio.isAcceptableOrUnknown(
          data['image_aspect_ratio']!,
          _imageAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('artists_json')) {
      context.handle(
        _artistsJsonMeta,
        artistsJson.isAcceptableOrUnknown(
          data['artists_json']!,
          _artistsJsonMeta,
        ),
      );
    }
    if (data.containsKey('album_item_id')) {
      context.handle(
        _albumItemIdMeta,
        albumItemId.isAcceptableOrUnknown(
          data['album_item_id']!,
          _albumItemIdMeta,
        ),
      );
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('duration_micros')) {
      context.handle(
        _durationMicrosMeta,
        durationMicros.isAcceptableOrUnknown(
          data['duration_micros']!,
          _durationMicrosMeta,
        ),
      );
    }
    if (data.containsKey('production_year')) {
      context.handle(
        _productionYearMeta,
        productionYear.isAcceptableOrUnknown(
          data['production_year']!,
          _productionYearMeta,
        ),
      );
    }
    if (data.containsKey('child_count')) {
      context.handle(
        _childCountMeta,
        childCount.isAcceptableOrUnknown(data['child_count']!, _childCountMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, itemId};
  @override
  CachedMediaItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedMediaItemRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability'],
      )!,
      imageItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_item_id'],
      ),
      imageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_kind'],
      ),
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      ),
      imageAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_aspect_ratio'],
      ),
      artistsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artists_json'],
      ),
      albumItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_item_id'],
      ),
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      durationMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_micros'],
      ),
      productionYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}production_year'],
      ),
      childCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}child_count'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedMediaItemsTable createAlias(String alias) {
    return $CachedMediaItemsTable(attachedDatabase, alias);
  }
}

class CachedMediaItemRow extends DataClass
    implements Insertable<CachedMediaItemRow> {
  /// Jellyfinity's local id for the server the item came from.
  final String serverId;

  /// The item's id on that server.
  final String itemId;

  /// `MediaKind.name` — how a row is turned back into the right entity.
  final String kind;
  final String name;

  /// `MediaAvailability.name` as the server reported it when the row was
  /// written. Preserves marks the server made (a missing episode); the
  /// "you are offline" downgrade is applied at read time, not stored.
  final String availability;

  /// The artwork pointer, flattened. `image_item_id` is the item that
  /// *owns* the image, which for a song is its album.
  final String? imageItemId;
  final String? imageKind;
  final String? imageTag;
  final double? imageAspectRatio;

  /// Artist credits as a JSON array of `{name, id?}` objects.
  ///
  /// Credits are a display list read only with the item that owns them,
  /// never queried across items, so a join table would buy nothing and
  /// cost a query per row on a 130k-row table.
  final String? artistsJson;

  /// The album a track belongs to, kept as id *and* name so a cached
  /// track row renders without a second lookup.
  final String? albumItemId;
  final String? albumName;
  final int? trackNumber;
  final int? discNumber;

  /// Running time in microseconds.
  final int? durationMicros;
  final int? productionYear;

  /// An album's track count or a playlist's item count, as reported.
  final int? childCount;

  /// When this row was last written (milliseconds since epoch).
  final int updatedAt;
  const CachedMediaItemRow({
    required this.serverId,
    required this.itemId,
    required this.kind,
    required this.name,
    required this.availability,
    this.imageItemId,
    this.imageKind,
    this.imageTag,
    this.imageAspectRatio,
    this.artistsJson,
    this.albumItemId,
    this.albumName,
    this.trackNumber,
    this.discNumber,
    this.durationMicros,
    this.productionYear,
    this.childCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['item_id'] = Variable<String>(itemId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['availability'] = Variable<String>(availability);
    if (!nullToAbsent || imageItemId != null) {
      map['image_item_id'] = Variable<String>(imageItemId);
    }
    if (!nullToAbsent || imageKind != null) {
      map['image_kind'] = Variable<String>(imageKind);
    }
    if (!nullToAbsent || imageTag != null) {
      map['image_tag'] = Variable<String>(imageTag);
    }
    if (!nullToAbsent || imageAspectRatio != null) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio);
    }
    if (!nullToAbsent || artistsJson != null) {
      map['artists_json'] = Variable<String>(artistsJson);
    }
    if (!nullToAbsent || albumItemId != null) {
      map['album_item_id'] = Variable<String>(albumItemId);
    }
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || durationMicros != null) {
      map['duration_micros'] = Variable<int>(durationMicros);
    }
    if (!nullToAbsent || productionYear != null) {
      map['production_year'] = Variable<int>(productionYear);
    }
    if (!nullToAbsent || childCount != null) {
      map['child_count'] = Variable<int>(childCount);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CachedMediaItemsCompanion toCompanion(bool nullToAbsent) {
    return CachedMediaItemsCompanion(
      serverId: Value(serverId),
      itemId: Value(itemId),
      kind: Value(kind),
      name: Value(name),
      availability: Value(availability),
      imageItemId: imageItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageItemId),
      imageKind: imageKind == null && nullToAbsent
          ? const Value.absent()
          : Value(imageKind),
      imageTag: imageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTag),
      imageAspectRatio: imageAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAspectRatio),
      artistsJson: artistsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(artistsJson),
      albumItemId: albumItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumItemId),
      albumName: albumName == null && nullToAbsent
          ? const Value.absent()
          : Value(albumName),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      durationMicros: durationMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMicros),
      productionYear: productionYear == null && nullToAbsent
          ? const Value.absent()
          : Value(productionYear),
      childCount: childCount == null && nullToAbsent
          ? const Value.absent()
          : Value(childCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedMediaItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedMediaItemRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      availability: serializer.fromJson<String>(json['availability']),
      imageItemId: serializer.fromJson<String?>(json['imageItemId']),
      imageKind: serializer.fromJson<String?>(json['imageKind']),
      imageTag: serializer.fromJson<String?>(json['imageTag']),
      imageAspectRatio: serializer.fromJson<double?>(json['imageAspectRatio']),
      artistsJson: serializer.fromJson<String?>(json['artistsJson']),
      albumItemId: serializer.fromJson<String?>(json['albumItemId']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      durationMicros: serializer.fromJson<int?>(json['durationMicros']),
      productionYear: serializer.fromJson<int?>(json['productionYear']),
      childCount: serializer.fromJson<int?>(json['childCount']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'itemId': serializer.toJson<String>(itemId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'availability': serializer.toJson<String>(availability),
      'imageItemId': serializer.toJson<String?>(imageItemId),
      'imageKind': serializer.toJson<String?>(imageKind),
      'imageTag': serializer.toJson<String?>(imageTag),
      'imageAspectRatio': serializer.toJson<double?>(imageAspectRatio),
      'artistsJson': serializer.toJson<String?>(artistsJson),
      'albumItemId': serializer.toJson<String?>(albumItemId),
      'albumName': serializer.toJson<String?>(albumName),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'discNumber': serializer.toJson<int?>(discNumber),
      'durationMicros': serializer.toJson<int?>(durationMicros),
      'productionYear': serializer.toJson<int?>(productionYear),
      'childCount': serializer.toJson<int?>(childCount),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CachedMediaItemRow copyWith({
    String? serverId,
    String? itemId,
    String? kind,
    String? name,
    String? availability,
    Value<String?> imageItemId = const Value.absent(),
    Value<String?> imageKind = const Value.absent(),
    Value<String?> imageTag = const Value.absent(),
    Value<double?> imageAspectRatio = const Value.absent(),
    Value<String?> artistsJson = const Value.absent(),
    Value<String?> albumItemId = const Value.absent(),
    Value<String?> albumName = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> durationMicros = const Value.absent(),
    Value<int?> productionYear = const Value.absent(),
    Value<int?> childCount = const Value.absent(),
    int? updatedAt,
  }) => CachedMediaItemRow(
    serverId: serverId ?? this.serverId,
    itemId: itemId ?? this.itemId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    availability: availability ?? this.availability,
    imageItemId: imageItemId.present ? imageItemId.value : this.imageItemId,
    imageKind: imageKind.present ? imageKind.value : this.imageKind,
    imageTag: imageTag.present ? imageTag.value : this.imageTag,
    imageAspectRatio: imageAspectRatio.present
        ? imageAspectRatio.value
        : this.imageAspectRatio,
    artistsJson: artistsJson.present ? artistsJson.value : this.artistsJson,
    albumItemId: albumItemId.present ? albumItemId.value : this.albumItemId,
    albumName: albumName.present ? albumName.value : this.albumName,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    durationMicros: durationMicros.present
        ? durationMicros.value
        : this.durationMicros,
    productionYear: productionYear.present
        ? productionYear.value
        : this.productionYear,
    childCount: childCount.present ? childCount.value : this.childCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedMediaItemRow copyWithCompanion(CachedMediaItemsCompanion data) {
    return CachedMediaItemRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
      imageItemId: data.imageItemId.present
          ? data.imageItemId.value
          : this.imageItemId,
      imageKind: data.imageKind.present ? data.imageKind.value : this.imageKind,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      imageAspectRatio: data.imageAspectRatio.present
          ? data.imageAspectRatio.value
          : this.imageAspectRatio,
      artistsJson: data.artistsJson.present
          ? data.artistsJson.value
          : this.artistsJson,
      albumItemId: data.albumItemId.present
          ? data.albumItemId.value
          : this.albumItemId,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      durationMicros: data.durationMicros.present
          ? data.durationMicros.value
          : this.durationMicros,
      productionYear: data.productionYear.present
          ? data.productionYear.value
          : this.productionYear,
      childCount: data.childCount.present
          ? data.childCount.value
          : this.childCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedMediaItemRow(')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('availability: $availability, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('artistsJson: $artistsJson, ')
          ..write('albumItemId: $albumItemId, ')
          ..write('albumName: $albumName, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMicros: $durationMicros, ')
          ..write('productionYear: $productionYear, ')
          ..write('childCount: $childCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    itemId,
    kind,
    name,
    availability,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    artistsJson,
    albumItemId,
    albumName,
    trackNumber,
    discNumber,
    durationMicros,
    productionYear,
    childCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMediaItemRow &&
          other.serverId == this.serverId &&
          other.itemId == this.itemId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.availability == this.availability &&
          other.imageItemId == this.imageItemId &&
          other.imageKind == this.imageKind &&
          other.imageTag == this.imageTag &&
          other.imageAspectRatio == this.imageAspectRatio &&
          other.artistsJson == this.artistsJson &&
          other.albumItemId == this.albumItemId &&
          other.albumName == this.albumName &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.durationMicros == this.durationMicros &&
          other.productionYear == this.productionYear &&
          other.childCount == this.childCount &&
          other.updatedAt == this.updatedAt);
}

class CachedMediaItemsCompanion extends UpdateCompanion<CachedMediaItemRow> {
  final Value<String> serverId;
  final Value<String> itemId;
  final Value<String> kind;
  final Value<String> name;
  final Value<String> availability;
  final Value<String?> imageItemId;
  final Value<String?> imageKind;
  final Value<String?> imageTag;
  final Value<double?> imageAspectRatio;
  final Value<String?> artistsJson;
  final Value<String?> albumItemId;
  final Value<String?> albumName;
  final Value<int?> trackNumber;
  final Value<int?> discNumber;
  final Value<int?> durationMicros;
  final Value<int?> productionYear;
  final Value<int?> childCount;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CachedMediaItemsCompanion({
    this.serverId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.availability = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.artistsJson = const Value.absent(),
    this.albumItemId = const Value.absent(),
    this.albumName = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMicros = const Value.absent(),
    this.productionYear = const Value.absent(),
    this.childCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedMediaItemsCompanion.insert({
    required String serverId,
    required String itemId,
    required String kind,
    required String name,
    required String availability,
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.artistsJson = const Value.absent(),
    this.albumItemId = const Value.absent(),
    this.albumName = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMicros = const Value.absent(),
    this.productionYear = const Value.absent(),
    this.childCount = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       itemId = Value(itemId),
       kind = Value(kind),
       name = Value(name),
       availability = Value(availability),
       updatedAt = Value(updatedAt);
  static Insertable<CachedMediaItemRow> custom({
    Expression<String>? serverId,
    Expression<String>? itemId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? availability,
    Expression<String>? imageItemId,
    Expression<String>? imageKind,
    Expression<String>? imageTag,
    Expression<double>? imageAspectRatio,
    Expression<String>? artistsJson,
    Expression<String>? albumItemId,
    Expression<String>? albumName,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? durationMicros,
    Expression<int>? productionYear,
    Expression<int>? childCount,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (itemId != null) 'item_id': itemId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (availability != null) 'availability': availability,
      if (imageItemId != null) 'image_item_id': imageItemId,
      if (imageKind != null) 'image_kind': imageKind,
      if (imageTag != null) 'image_tag': imageTag,
      if (imageAspectRatio != null) 'image_aspect_ratio': imageAspectRatio,
      if (artistsJson != null) 'artists_json': artistsJson,
      if (albumItemId != null) 'album_item_id': albumItemId,
      if (albumName != null) 'album_name': albumName,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (durationMicros != null) 'duration_micros': durationMicros,
      if (productionYear != null) 'production_year': productionYear,
      if (childCount != null) 'child_count': childCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedMediaItemsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? itemId,
    Value<String>? kind,
    Value<String>? name,
    Value<String>? availability,
    Value<String?>? imageItemId,
    Value<String?>? imageKind,
    Value<String?>? imageTag,
    Value<double?>? imageAspectRatio,
    Value<String?>? artistsJson,
    Value<String?>? albumItemId,
    Value<String?>? albumName,
    Value<int?>? trackNumber,
    Value<int?>? discNumber,
    Value<int?>? durationMicros,
    Value<int?>? productionYear,
    Value<int?>? childCount,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedMediaItemsCompanion(
      serverId: serverId ?? this.serverId,
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      availability: availability ?? this.availability,
      imageItemId: imageItemId ?? this.imageItemId,
      imageKind: imageKind ?? this.imageKind,
      imageTag: imageTag ?? this.imageTag,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      artistsJson: artistsJson ?? this.artistsJson,
      albumItemId: albumItemId ?? this.albumItemId,
      albumName: albumName ?? this.albumName,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMicros: durationMicros ?? this.durationMicros,
      productionYear: productionYear ?? this.productionYear,
      childCount: childCount ?? this.childCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (imageItemId.present) {
      map['image_item_id'] = Variable<String>(imageItemId.value);
    }
    if (imageKind.present) {
      map['image_kind'] = Variable<String>(imageKind.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (imageAspectRatio.present) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio.value);
    }
    if (artistsJson.present) {
      map['artists_json'] = Variable<String>(artistsJson.value);
    }
    if (albumItemId.present) {
      map['album_item_id'] = Variable<String>(albumItemId.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (durationMicros.present) {
      map['duration_micros'] = Variable<int>(durationMicros.value);
    }
    if (productionYear.present) {
      map['production_year'] = Variable<int>(productionYear.value);
    }
    if (childCount.present) {
      map['child_count'] = Variable<int>(childCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedMediaItemsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('availability: $availability, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('artistsJson: $artistsJson, ')
          ..write('albumItemId: $albumItemId, ')
          ..write('albumName: $albumName, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMicros: $durationMicros, ')
          ..write('productionYear: $productionYear, ')
          ..write('childCount: $childCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCollectionsTable extends CachedCollections
    with TableInfo<$CachedCollectionsTable, CachedCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionKeyMeta = const VerificationMeta(
    'collectionKey',
  );
  @override
  late final GeneratedColumn<String> collectionKey = GeneratedColumn<String>(
    'collection_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCountMeta = const VerificationMeta(
    'totalCount',
  );
  @override
  late final GeneratedColumn<int> totalCount = GeneratedColumn<int>(
    'total_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    collectionKey,
    totalCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('collection_key')) {
      context.handle(
        _collectionKeyMeta,
        collectionKey.isAcceptableOrUnknown(
          data['collection_key']!,
          _collectionKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionKeyMeta);
    }
    if (data.containsKey('total_count')) {
      context.handle(
        _totalCountMeta,
        totalCount.isAcceptableOrUnknown(data['total_count']!, _totalCountMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCountMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, collectionKey};
  @override
  CachedCollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCollectionRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      collectionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_key'],
      )!,
      totalCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedCollectionsTable createAlias(String alias) {
    return $CachedCollectionsTable(attachedDatabase, alias);
  }
}

class CachedCollectionRow extends DataClass
    implements Insertable<CachedCollectionRow> {
  final String serverId;

  /// The query in one string, e.g. `albums` or `tracks:album=<item id>`.
  final String collectionKey;
  final int totalCount;
  final int updatedAt;
  const CachedCollectionRow({
    required this.serverId,
    required this.collectionKey,
    required this.totalCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['collection_key'] = Variable<String>(collectionKey);
    map['total_count'] = Variable<int>(totalCount);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CachedCollectionsCompanion toCompanion(bool nullToAbsent) {
    return CachedCollectionsCompanion(
      serverId: Value(serverId),
      collectionKey: Value(collectionKey),
      totalCount: Value(totalCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCollectionRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      collectionKey: serializer.fromJson<String>(json['collectionKey']),
      totalCount: serializer.fromJson<int>(json['totalCount']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'collectionKey': serializer.toJson<String>(collectionKey),
      'totalCount': serializer.toJson<int>(totalCount),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CachedCollectionRow copyWith({
    String? serverId,
    String? collectionKey,
    int? totalCount,
    int? updatedAt,
  }) => CachedCollectionRow(
    serverId: serverId ?? this.serverId,
    collectionKey: collectionKey ?? this.collectionKey,
    totalCount: totalCount ?? this.totalCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedCollectionRow copyWithCompanion(CachedCollectionsCompanion data) {
    return CachedCollectionRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      collectionKey: data.collectionKey.present
          ? data.collectionKey.value
          : this.collectionKey,
      totalCount: data.totalCount.present
          ? data.totalCount.value
          : this.totalCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCollectionRow(')
          ..write('serverId: $serverId, ')
          ..write('collectionKey: $collectionKey, ')
          ..write('totalCount: $totalCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(serverId, collectionKey, totalCount, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCollectionRow &&
          other.serverId == this.serverId &&
          other.collectionKey == this.collectionKey &&
          other.totalCount == this.totalCount &&
          other.updatedAt == this.updatedAt);
}

class CachedCollectionsCompanion extends UpdateCompanion<CachedCollectionRow> {
  final Value<String> serverId;
  final Value<String> collectionKey;
  final Value<int> totalCount;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CachedCollectionsCompanion({
    this.serverId = const Value.absent(),
    this.collectionKey = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCollectionsCompanion.insert({
    required String serverId,
    required String collectionKey,
    required int totalCount,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       collectionKey = Value(collectionKey),
       totalCount = Value(totalCount),
       updatedAt = Value(updatedAt);
  static Insertable<CachedCollectionRow> custom({
    Expression<String>? serverId,
    Expression<String>? collectionKey,
    Expression<int>? totalCount,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (collectionKey != null) 'collection_key': collectionKey,
      if (totalCount != null) 'total_count': totalCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCollectionsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? collectionKey,
    Value<int>? totalCount,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedCollectionsCompanion(
      serverId: serverId ?? this.serverId,
      collectionKey: collectionKey ?? this.collectionKey,
      totalCount: totalCount ?? this.totalCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (collectionKey.present) {
      map['collection_key'] = Variable<String>(collectionKey.value);
    }
    if (totalCount.present) {
      map['total_count'] = Variable<int>(totalCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCollectionsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('collectionKey: $collectionKey, ')
          ..write('totalCount: $totalCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedCollectionEntriesTable extends CachedCollectionEntries
    with TableInfo<$CachedCollectionEntriesTable, CachedCollectionEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCollectionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionKeyMeta = const VerificationMeta(
    'collectionKey',
  );
  @override
  late final GeneratedColumn<String> collectionKey = GeneratedColumn<String>(
    'collection_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unavailableReasonMeta = const VerificationMeta(
    'unavailableReason',
  );
  @override
  late final GeneratedColumn<String> unavailableReason =
      GeneratedColumn<String>(
        'unavailable_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    collectionKey,
    position,
    itemId,
    unavailableReason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_collection_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCollectionEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('collection_key')) {
      context.handle(
        _collectionKeyMeta,
        collectionKey.isAcceptableOrUnknown(
          data['collection_key']!,
          _collectionKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_collectionKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('unavailable_reason')) {
      context.handle(
        _unavailableReasonMeta,
        unavailableReason.isAcceptableOrUnknown(
          data['unavailable_reason']!,
          _unavailableReasonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, collectionKey, position};
  @override
  CachedCollectionEntryRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCollectionEntryRow(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      collectionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      unavailableReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unavailable_reason'],
      ),
    );
  }

  @override
  $CachedCollectionEntriesTable createAlias(String alias) {
    return $CachedCollectionEntriesTable(attachedDatabase, alias);
  }
}

class CachedCollectionEntryRow extends DataClass
    implements Insertable<CachedCollectionEntryRow> {
  final String serverId;
  final String collectionKey;

  /// The entry's index within the whole collection, not within a window.
  final int position;

  /// The `CachedMediaItems` row this position points at.
  final String itemId;

  /// Set when this position could not be turned into an item.
  final String? unavailableReason;
  const CachedCollectionEntryRow({
    required this.serverId,
    required this.collectionKey,
    required this.position,
    required this.itemId,
    this.unavailableReason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['collection_key'] = Variable<String>(collectionKey);
    map['position'] = Variable<int>(position);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || unavailableReason != null) {
      map['unavailable_reason'] = Variable<String>(unavailableReason);
    }
    return map;
  }

  CachedCollectionEntriesCompanion toCompanion(bool nullToAbsent) {
    return CachedCollectionEntriesCompanion(
      serverId: Value(serverId),
      collectionKey: Value(collectionKey),
      position: Value(position),
      itemId: Value(itemId),
      unavailableReason: unavailableReason == null && nullToAbsent
          ? const Value.absent()
          : Value(unavailableReason),
    );
  }

  factory CachedCollectionEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCollectionEntryRow(
      serverId: serializer.fromJson<String>(json['serverId']),
      collectionKey: serializer.fromJson<String>(json['collectionKey']),
      position: serializer.fromJson<int>(json['position']),
      itemId: serializer.fromJson<String>(json['itemId']),
      unavailableReason: serializer.fromJson<String?>(
        json['unavailableReason'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'collectionKey': serializer.toJson<String>(collectionKey),
      'position': serializer.toJson<int>(position),
      'itemId': serializer.toJson<String>(itemId),
      'unavailableReason': serializer.toJson<String?>(unavailableReason),
    };
  }

  CachedCollectionEntryRow copyWith({
    String? serverId,
    String? collectionKey,
    int? position,
    String? itemId,
    Value<String?> unavailableReason = const Value.absent(),
  }) => CachedCollectionEntryRow(
    serverId: serverId ?? this.serverId,
    collectionKey: collectionKey ?? this.collectionKey,
    position: position ?? this.position,
    itemId: itemId ?? this.itemId,
    unavailableReason: unavailableReason.present
        ? unavailableReason.value
        : this.unavailableReason,
  );
  CachedCollectionEntryRow copyWithCompanion(
    CachedCollectionEntriesCompanion data,
  ) {
    return CachedCollectionEntryRow(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      collectionKey: data.collectionKey.present
          ? data.collectionKey.value
          : this.collectionKey,
      position: data.position.present ? data.position.value : this.position,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      unavailableReason: data.unavailableReason.present
          ? data.unavailableReason.value
          : this.unavailableReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCollectionEntryRow(')
          ..write('serverId: $serverId, ')
          ..write('collectionKey: $collectionKey, ')
          ..write('position: $position, ')
          ..write('itemId: $itemId, ')
          ..write('unavailableReason: $unavailableReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(serverId, collectionKey, position, itemId, unavailableReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCollectionEntryRow &&
          other.serverId == this.serverId &&
          other.collectionKey == this.collectionKey &&
          other.position == this.position &&
          other.itemId == this.itemId &&
          other.unavailableReason == this.unavailableReason);
}

class CachedCollectionEntriesCompanion
    extends UpdateCompanion<CachedCollectionEntryRow> {
  final Value<String> serverId;
  final Value<String> collectionKey;
  final Value<int> position;
  final Value<String> itemId;
  final Value<String?> unavailableReason;
  final Value<int> rowid;
  const CachedCollectionEntriesCompanion({
    this.serverId = const Value.absent(),
    this.collectionKey = const Value.absent(),
    this.position = const Value.absent(),
    this.itemId = const Value.absent(),
    this.unavailableReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCollectionEntriesCompanion.insert({
    required String serverId,
    required String collectionKey,
    required int position,
    required String itemId,
    this.unavailableReason = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       collectionKey = Value(collectionKey),
       position = Value(position),
       itemId = Value(itemId);
  static Insertable<CachedCollectionEntryRow> custom({
    Expression<String>? serverId,
    Expression<String>? collectionKey,
    Expression<int>? position,
    Expression<String>? itemId,
    Expression<String>? unavailableReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (collectionKey != null) 'collection_key': collectionKey,
      if (position != null) 'position': position,
      if (itemId != null) 'item_id': itemId,
      if (unavailableReason != null) 'unavailable_reason': unavailableReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCollectionEntriesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? collectionKey,
    Value<int>? position,
    Value<String>? itemId,
    Value<String?>? unavailableReason,
    Value<int>? rowid,
  }) {
    return CachedCollectionEntriesCompanion(
      serverId: serverId ?? this.serverId,
      collectionKey: collectionKey ?? this.collectionKey,
      position: position ?? this.position,
      itemId: itemId ?? this.itemId,
      unavailableReason: unavailableReason ?? this.unavailableReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (collectionKey.present) {
      map['collection_key'] = Variable<String>(collectionKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (unavailableReason.present) {
      map['unavailable_reason'] = Variable<String>(unavailableReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCollectionEntriesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('collectionKey: $collectionKey, ')
          ..write('position: $position, ')
          ..write('itemId: $itemId, ')
          ..write('unavailableReason: $unavailableReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueueEntriesTable extends QueueEntries
    with TableInfo<$QueueEntriesTable, QueueEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMicrosMeta = const VerificationMeta(
    'durationMicros',
  );
  @override
  late final GeneratedColumn<int> durationMicros = GeneratedColumn<int>(
    'duration_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageItemIdMeta = const VerificationMeta(
    'imageItemId',
  );
  @override
  late final GeneratedColumn<String> imageItemId = GeneratedColumn<String>(
    'image_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageKindMeta = const VerificationMeta(
    'imageKind',
  );
  @override
  late final GeneratedColumn<String> imageKind = GeneratedColumn<String>(
    'image_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAspectRatioMeta = const VerificationMeta(
    'imageAspectRatio',
  );
  @override
  late final GeneratedColumn<double> imageAspectRatio = GeneratedColumn<double>(
    'image_aspect_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('remoteOnly'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    position,
    serverId,
    itemId,
    title,
    artist,
    albumName,
    durationMicros,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    availability,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueueEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('duration_micros')) {
      context.handle(
        _durationMicrosMeta,
        durationMicros.isAcceptableOrUnknown(
          data['duration_micros']!,
          _durationMicrosMeta,
        ),
      );
    }
    if (data.containsKey('image_item_id')) {
      context.handle(
        _imageItemIdMeta,
        imageItemId.isAcceptableOrUnknown(
          data['image_item_id']!,
          _imageItemIdMeta,
        ),
      );
    }
    if (data.containsKey('image_kind')) {
      context.handle(
        _imageKindMeta,
        imageKind.isAcceptableOrUnknown(data['image_kind']!, _imageKindMeta),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    }
    if (data.containsKey('image_aspect_ratio')) {
      context.handle(
        _imageAspectRatioMeta,
        imageAspectRatio.isAcceptableOrUnknown(
          data['image_aspect_ratio']!,
          _imageAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {position};
  @override
  QueueEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueueEntryRow(
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      durationMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_micros'],
      ),
      imageItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_item_id'],
      ),
      imageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_kind'],
      ),
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      ),
      imageAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_aspect_ratio'],
      ),
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability'],
      )!,
    );
  }

  @override
  $QueueEntriesTable createAlias(String alias) {
    return $QueueEntriesTable(attachedDatabase, alias);
  }
}

class QueueEntryRow extends DataClass implements Insertable<QueueEntryRow> {
  /// The entry's position in the queue's own (non-shuffled) order.
  final int position;
  final String serverId;
  final String itemId;
  final String title;

  /// The joined artist credit line, already formatted for display.
  final String? artist;
  final String? albumName;
  final int? durationMicros;
  final String? imageItemId;
  final String? imageKind;
  final String? imageTag;
  final double? imageAspectRatio;

  /// `MediaAvailability.name`. Carries a `remoteUnavailable` mark
  /// (`PlaybackEngine.failureStream`) forward across a restart, so a
  /// track that failed before the app closed is still shown as
  /// unavailable rather than looking playable again.
  final String availability;
  const QueueEntryRow({
    required this.position,
    required this.serverId,
    required this.itemId,
    required this.title,
    this.artist,
    this.albumName,
    this.durationMicros,
    this.imageItemId,
    this.imageKind,
    this.imageTag,
    this.imageAspectRatio,
    required this.availability,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['position'] = Variable<int>(position);
    map['server_id'] = Variable<String>(serverId);
    map['item_id'] = Variable<String>(itemId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || durationMicros != null) {
      map['duration_micros'] = Variable<int>(durationMicros);
    }
    if (!nullToAbsent || imageItemId != null) {
      map['image_item_id'] = Variable<String>(imageItemId);
    }
    if (!nullToAbsent || imageKind != null) {
      map['image_kind'] = Variable<String>(imageKind);
    }
    if (!nullToAbsent || imageTag != null) {
      map['image_tag'] = Variable<String>(imageTag);
    }
    if (!nullToAbsent || imageAspectRatio != null) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio);
    }
    map['availability'] = Variable<String>(availability);
    return map;
  }

  QueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return QueueEntriesCompanion(
      position: Value(position),
      serverId: Value(serverId),
      itemId: Value(itemId),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      albumName: albumName == null && nullToAbsent
          ? const Value.absent()
          : Value(albumName),
      durationMicros: durationMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMicros),
      imageItemId: imageItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageItemId),
      imageKind: imageKind == null && nullToAbsent
          ? const Value.absent()
          : Value(imageKind),
      imageTag: imageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTag),
      imageAspectRatio: imageAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAspectRatio),
      availability: Value(availability),
    );
  }

  factory QueueEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueueEntryRow(
      position: serializer.fromJson<int>(json['position']),
      serverId: serializer.fromJson<String>(json['serverId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      durationMicros: serializer.fromJson<int?>(json['durationMicros']),
      imageItemId: serializer.fromJson<String?>(json['imageItemId']),
      imageKind: serializer.fromJson<String?>(json['imageKind']),
      imageTag: serializer.fromJson<String?>(json['imageTag']),
      imageAspectRatio: serializer.fromJson<double?>(json['imageAspectRatio']),
      availability: serializer.fromJson<String>(json['availability']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'position': serializer.toJson<int>(position),
      'serverId': serializer.toJson<String>(serverId),
      'itemId': serializer.toJson<String>(itemId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'albumName': serializer.toJson<String?>(albumName),
      'durationMicros': serializer.toJson<int?>(durationMicros),
      'imageItemId': serializer.toJson<String?>(imageItemId),
      'imageKind': serializer.toJson<String?>(imageKind),
      'imageTag': serializer.toJson<String?>(imageTag),
      'imageAspectRatio': serializer.toJson<double?>(imageAspectRatio),
      'availability': serializer.toJson<String>(availability),
    };
  }

  QueueEntryRow copyWith({
    int? position,
    String? serverId,
    String? itemId,
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> albumName = const Value.absent(),
    Value<int?> durationMicros = const Value.absent(),
    Value<String?> imageItemId = const Value.absent(),
    Value<String?> imageKind = const Value.absent(),
    Value<String?> imageTag = const Value.absent(),
    Value<double?> imageAspectRatio = const Value.absent(),
    String? availability,
  }) => QueueEntryRow(
    position: position ?? this.position,
    serverId: serverId ?? this.serverId,
    itemId: itemId ?? this.itemId,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    albumName: albumName.present ? albumName.value : this.albumName,
    durationMicros: durationMicros.present
        ? durationMicros.value
        : this.durationMicros,
    imageItemId: imageItemId.present ? imageItemId.value : this.imageItemId,
    imageKind: imageKind.present ? imageKind.value : this.imageKind,
    imageTag: imageTag.present ? imageTag.value : this.imageTag,
    imageAspectRatio: imageAspectRatio.present
        ? imageAspectRatio.value
        : this.imageAspectRatio,
    availability: availability ?? this.availability,
  );
  QueueEntryRow copyWithCompanion(QueueEntriesCompanion data) {
    return QueueEntryRow(
      position: data.position.present ? data.position.value : this.position,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      durationMicros: data.durationMicros.present
          ? data.durationMicros.value
          : this.durationMicros,
      imageItemId: data.imageItemId.present
          ? data.imageItemId.value
          : this.imageItemId,
      imageKind: data.imageKind.present ? data.imageKind.value : this.imageKind,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      imageAspectRatio: data.imageAspectRatio.present
          ? data.imageAspectRatio.value
          : this.imageAspectRatio,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntryRow(')
          ..write('position: $position, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('albumName: $albumName, ')
          ..write('durationMicros: $durationMicros, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('availability: $availability')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    position,
    serverId,
    itemId,
    title,
    artist,
    albumName,
    durationMicros,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    availability,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueueEntryRow &&
          other.position == this.position &&
          other.serverId == this.serverId &&
          other.itemId == this.itemId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.albumName == this.albumName &&
          other.durationMicros == this.durationMicros &&
          other.imageItemId == this.imageItemId &&
          other.imageKind == this.imageKind &&
          other.imageTag == this.imageTag &&
          other.imageAspectRatio == this.imageAspectRatio &&
          other.availability == this.availability);
}

class QueueEntriesCompanion extends UpdateCompanion<QueueEntryRow> {
  final Value<int> position;
  final Value<String> serverId;
  final Value<String> itemId;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> albumName;
  final Value<int?> durationMicros;
  final Value<String?> imageItemId;
  final Value<String?> imageKind;
  final Value<String?> imageTag;
  final Value<double?> imageAspectRatio;
  final Value<String> availability;
  const QueueEntriesCompanion({
    this.position = const Value.absent(),
    this.serverId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.albumName = const Value.absent(),
    this.durationMicros = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.availability = const Value.absent(),
  });
  QueueEntriesCompanion.insert({
    this.position = const Value.absent(),
    required String serverId,
    required String itemId,
    required String title,
    this.artist = const Value.absent(),
    this.albumName = const Value.absent(),
    this.durationMicros = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.availability = const Value.absent(),
  }) : serverId = Value(serverId),
       itemId = Value(itemId),
       title = Value(title);
  static Insertable<QueueEntryRow> custom({
    Expression<int>? position,
    Expression<String>? serverId,
    Expression<String>? itemId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? albumName,
    Expression<int>? durationMicros,
    Expression<String>? imageItemId,
    Expression<String>? imageKind,
    Expression<String>? imageTag,
    Expression<double>? imageAspectRatio,
    Expression<String>? availability,
  }) {
    return RawValuesInsertable({
      if (position != null) 'position': position,
      if (serverId != null) 'server_id': serverId,
      if (itemId != null) 'item_id': itemId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (albumName != null) 'album_name': albumName,
      if (durationMicros != null) 'duration_micros': durationMicros,
      if (imageItemId != null) 'image_item_id': imageItemId,
      if (imageKind != null) 'image_kind': imageKind,
      if (imageTag != null) 'image_tag': imageTag,
      if (imageAspectRatio != null) 'image_aspect_ratio': imageAspectRatio,
      if (availability != null) 'availability': availability,
    });
  }

  QueueEntriesCompanion copyWith({
    Value<int>? position,
    Value<String>? serverId,
    Value<String>? itemId,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? albumName,
    Value<int?>? durationMicros,
    Value<String?>? imageItemId,
    Value<String?>? imageKind,
    Value<String?>? imageTag,
    Value<double?>? imageAspectRatio,
    Value<String>? availability,
  }) {
    return QueueEntriesCompanion(
      position: position ?? this.position,
      serverId: serverId ?? this.serverId,
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumName: albumName ?? this.albumName,
      durationMicros: durationMicros ?? this.durationMicros,
      imageItemId: imageItemId ?? this.imageItemId,
      imageKind: imageKind ?? this.imageKind,
      imageTag: imageTag ?? this.imageTag,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      availability: availability ?? this.availability,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (durationMicros.present) {
      map['duration_micros'] = Variable<int>(durationMicros.value);
    }
    if (imageItemId.present) {
      map['image_item_id'] = Variable<String>(imageItemId.value);
    }
    if (imageKind.present) {
      map['image_kind'] = Variable<String>(imageKind.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (imageAspectRatio.present) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueueEntriesCompanion(')
          ..write('position: $position, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('albumName: $albumName, ')
          ..write('durationMicros: $durationMicros, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('availability: $availability')
          ..write(')'))
        .toString();
  }
}

class $TrackDownloadsTable extends TrackDownloads
    with TableInfo<$TrackDownloadsTable, TrackDownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackDownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverGoneMeta = const VerificationMeta(
    'serverGone',
  );
  @override
  late final GeneratedColumn<bool> serverGone = GeneratedColumn<bool>(
    'server_gone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("server_gone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _failureReasonMeta = const VerificationMeta(
    'failureReason',
  );
  @override
  late final GeneratedColumn<String> failureReason = GeneratedColumn<String>(
    'failure_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receivedBytesMeta = const VerificationMeta(
    'receivedBytes',
  );
  @override
  late final GeneratedColumn<int> receivedBytes = GeneratedColumn<int>(
    'received_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistsJsonMeta = const VerificationMeta(
    'artistsJson',
  );
  @override
  late final GeneratedColumn<String> artistsJson = GeneratedColumn<String>(
    'artists_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumItemIdMeta = const VerificationMeta(
    'albumItemId',
  );
  @override
  late final GeneratedColumn<String> albumItemId = GeneratedColumn<String>(
    'album_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumNameMeta = const VerificationMeta(
    'albumName',
  );
  @override
  late final GeneratedColumn<String> albumName = GeneratedColumn<String>(
    'album_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMicrosMeta = const VerificationMeta(
    'durationMicros',
  );
  @override
  late final GeneratedColumn<int> durationMicros = GeneratedColumn<int>(
    'duration_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _normalizationGainMeta = const VerificationMeta(
    'normalizationGain',
  );
  @override
  late final GeneratedColumn<double> normalizationGain =
      GeneratedColumn<double>(
        'normalization_gain',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _imageItemIdMeta = const VerificationMeta(
    'imageItemId',
  );
  @override
  late final GeneratedColumn<String> imageItemId = GeneratedColumn<String>(
    'image_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageKindMeta = const VerificationMeta(
    'imageKind',
  );
  @override
  late final GeneratedColumn<String> imageKind = GeneratedColumn<String>(
    'image_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAspectRatioMeta = const VerificationMeta(
    'imageAspectRatio',
  );
  @override
  late final GeneratedColumn<double> imageAspectRatio = GeneratedColumn<double>(
    'image_aspect_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestedAtMeta = const VerificationMeta(
    'requestedAt',
  );
  @override
  late final GeneratedColumn<int> requestedAt = GeneratedColumn<int>(
    'requested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    serverId,
    itemId,
    state,
    serverGone,
    failureReason,
    receivedBytes,
    totalBytes,
    title,
    artistsJson,
    albumItemId,
    albumName,
    trackNumber,
    discNumber,
    durationMicros,
    normalizationGain,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    requestedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackDownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('server_gone')) {
      context.handle(
        _serverGoneMeta,
        serverGone.isAcceptableOrUnknown(data['server_gone']!, _serverGoneMeta),
      );
    }
    if (data.containsKey('failure_reason')) {
      context.handle(
        _failureReasonMeta,
        failureReason.isAcceptableOrUnknown(
          data['failure_reason']!,
          _failureReasonMeta,
        ),
      );
    }
    if (data.containsKey('received_bytes')) {
      context.handle(
        _receivedBytesMeta,
        receivedBytes.isAcceptableOrUnknown(
          data['received_bytes']!,
          _receivedBytesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artists_json')) {
      context.handle(
        _artistsJsonMeta,
        artistsJson.isAcceptableOrUnknown(
          data['artists_json']!,
          _artistsJsonMeta,
        ),
      );
    }
    if (data.containsKey('album_item_id')) {
      context.handle(
        _albumItemIdMeta,
        albumItemId.isAcceptableOrUnknown(
          data['album_item_id']!,
          _albumItemIdMeta,
        ),
      );
    }
    if (data.containsKey('album_name')) {
      context.handle(
        _albumNameMeta,
        albumName.isAcceptableOrUnknown(data['album_name']!, _albumNameMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('duration_micros')) {
      context.handle(
        _durationMicrosMeta,
        durationMicros.isAcceptableOrUnknown(
          data['duration_micros']!,
          _durationMicrosMeta,
        ),
      );
    }
    if (data.containsKey('normalization_gain')) {
      context.handle(
        _normalizationGainMeta,
        normalizationGain.isAcceptableOrUnknown(
          data['normalization_gain']!,
          _normalizationGainMeta,
        ),
      );
    }
    if (data.containsKey('image_item_id')) {
      context.handle(
        _imageItemIdMeta,
        imageItemId.isAcceptableOrUnknown(
          data['image_item_id']!,
          _imageItemIdMeta,
        ),
      );
    }
    if (data.containsKey('image_kind')) {
      context.handle(
        _imageKindMeta,
        imageKind.isAcceptableOrUnknown(data['image_kind']!, _imageKindMeta),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    }
    if (data.containsKey('image_aspect_ratio')) {
      context.handle(
        _imageAspectRatioMeta,
        imageAspectRatio.isAcceptableOrUnknown(
          data['image_aspect_ratio']!,
          _imageAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('requested_at')) {
      context.handle(
        _requestedAtMeta,
        requestedAt.isAcceptableOrUnknown(
          data['requested_at']!,
          _requestedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey, serverId, itemId};
  @override
  TrackDownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackDownloadRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      serverGone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}server_gone'],
      )!,
      failureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_reason'],
      ),
      receivedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_bytes'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artistsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artists_json'],
      ),
      albumItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_item_id'],
      ),
      albumName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_name'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      durationMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_micros'],
      ),
      normalizationGain: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}normalization_gain'],
      ),
      imageItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_item_id'],
      ),
      imageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_kind'],
      ),
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      ),
      imageAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_aspect_ratio'],
      ),
      requestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}requested_at'],
      )!,
    );
  }

  @override
  $TrackDownloadsTable createAlias(String alias) {
    return $TrackDownloadsTable(attachedDatabase, alias);
  }
}

class TrackDownloadRow extends DataClass
    implements Insertable<TrackDownloadRow> {
  /// The profile this download belongs to (v0.2.3): the server's local id
  /// and the Jellyfin user id joined with a slash. Empty on a row written
  /// before v0.2.3 — `DownloadsCubit`
  /// claims those for the first profile to open the app after the upgrade,
  /// which is the whole of the pre-v0.2.3 behaviour (one bucket, no
  /// isolation) carried forward.
  final String accountKey;
  final String serverId;
  final String itemId;

  /// `DownloadState.name`.
  final String state;

  /// Set once the server has been reached and no longer lists this track
  /// (v0.2.3). The file is kept and shown as "Only on this device" rather
  /// than deleted or reported as a server error; never set from a merely
  /// unreachable server.
  final bool serverGone;

  /// `DownloadFailureReason.name`, set only for a failed row.
  final String? failureReason;

  /// Bytes on the device so far, so a resumed transfer reports honest
  /// progress after a restart instead of starting its bar at zero.
  final int receivedBytes;

  /// The file's full size once the server has reported one; null while
  /// that is still unknown.
  final int? totalBytes;
  final String title;

  /// Artist credits as a JSON array of `{name, id?}` objects, encoded the
  /// same way [CachedMediaItems.artistsJson] encodes them.
  final String? artistsJson;
  final String? albumItemId;
  final String? albumName;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMicros;
  final double? normalizationGain;
  final String? imageItemId;
  final String? imageKind;
  final String? imageTag;
  final double? imageAspectRatio;

  /// When the download was first requested (microseconds since epoch).
  /// This is the *order*: the engine takes pending downloads oldest
  /// first, so a long album does not overtake a song asked for before
  /// it. A monotonic insertion marker, like [SavedServers.addedAt].
  final int requestedAt;
  const TrackDownloadRow({
    required this.accountKey,
    required this.serverId,
    required this.itemId,
    required this.state,
    required this.serverGone,
    this.failureReason,
    required this.receivedBytes,
    this.totalBytes,
    required this.title,
    this.artistsJson,
    this.albumItemId,
    this.albumName,
    this.trackNumber,
    this.discNumber,
    this.durationMicros,
    this.normalizationGain,
    this.imageItemId,
    this.imageKind,
    this.imageTag,
    this.imageAspectRatio,
    required this.requestedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['server_id'] = Variable<String>(serverId);
    map['item_id'] = Variable<String>(itemId);
    map['state'] = Variable<String>(state);
    map['server_gone'] = Variable<bool>(serverGone);
    if (!nullToAbsent || failureReason != null) {
      map['failure_reason'] = Variable<String>(failureReason);
    }
    map['received_bytes'] = Variable<int>(receivedBytes);
    if (!nullToAbsent || totalBytes != null) {
      map['total_bytes'] = Variable<int>(totalBytes);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artistsJson != null) {
      map['artists_json'] = Variable<String>(artistsJson);
    }
    if (!nullToAbsent || albumItemId != null) {
      map['album_item_id'] = Variable<String>(albumItemId);
    }
    if (!nullToAbsent || albumName != null) {
      map['album_name'] = Variable<String>(albumName);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || durationMicros != null) {
      map['duration_micros'] = Variable<int>(durationMicros);
    }
    if (!nullToAbsent || normalizationGain != null) {
      map['normalization_gain'] = Variable<double>(normalizationGain);
    }
    if (!nullToAbsent || imageItemId != null) {
      map['image_item_id'] = Variable<String>(imageItemId);
    }
    if (!nullToAbsent || imageKind != null) {
      map['image_kind'] = Variable<String>(imageKind);
    }
    if (!nullToAbsent || imageTag != null) {
      map['image_tag'] = Variable<String>(imageTag);
    }
    if (!nullToAbsent || imageAspectRatio != null) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio);
    }
    map['requested_at'] = Variable<int>(requestedAt);
    return map;
  }

  TrackDownloadsCompanion toCompanion(bool nullToAbsent) {
    return TrackDownloadsCompanion(
      accountKey: Value(accountKey),
      serverId: Value(serverId),
      itemId: Value(itemId),
      state: Value(state),
      serverGone: Value(serverGone),
      failureReason: failureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(failureReason),
      receivedBytes: Value(receivedBytes),
      totalBytes: totalBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(totalBytes),
      title: Value(title),
      artistsJson: artistsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(artistsJson),
      albumItemId: albumItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumItemId),
      albumName: albumName == null && nullToAbsent
          ? const Value.absent()
          : Value(albumName),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      durationMicros: durationMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMicros),
      normalizationGain: normalizationGain == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizationGain),
      imageItemId: imageItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageItemId),
      imageKind: imageKind == null && nullToAbsent
          ? const Value.absent()
          : Value(imageKind),
      imageTag: imageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTag),
      imageAspectRatio: imageAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAspectRatio),
      requestedAt: Value(requestedAt),
    );
  }

  factory TrackDownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackDownloadRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String>(json['serverId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      state: serializer.fromJson<String>(json['state']),
      serverGone: serializer.fromJson<bool>(json['serverGone']),
      failureReason: serializer.fromJson<String?>(json['failureReason']),
      receivedBytes: serializer.fromJson<int>(json['receivedBytes']),
      totalBytes: serializer.fromJson<int?>(json['totalBytes']),
      title: serializer.fromJson<String>(json['title']),
      artistsJson: serializer.fromJson<String?>(json['artistsJson']),
      albumItemId: serializer.fromJson<String?>(json['albumItemId']),
      albumName: serializer.fromJson<String?>(json['albumName']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      durationMicros: serializer.fromJson<int?>(json['durationMicros']),
      normalizationGain: serializer.fromJson<double?>(
        json['normalizationGain'],
      ),
      imageItemId: serializer.fromJson<String?>(json['imageItemId']),
      imageKind: serializer.fromJson<String?>(json['imageKind']),
      imageTag: serializer.fromJson<String?>(json['imageTag']),
      imageAspectRatio: serializer.fromJson<double?>(json['imageAspectRatio']),
      requestedAt: serializer.fromJson<int>(json['requestedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String>(serverId),
      'itemId': serializer.toJson<String>(itemId),
      'state': serializer.toJson<String>(state),
      'serverGone': serializer.toJson<bool>(serverGone),
      'failureReason': serializer.toJson<String?>(failureReason),
      'receivedBytes': serializer.toJson<int>(receivedBytes),
      'totalBytes': serializer.toJson<int?>(totalBytes),
      'title': serializer.toJson<String>(title),
      'artistsJson': serializer.toJson<String?>(artistsJson),
      'albumItemId': serializer.toJson<String?>(albumItemId),
      'albumName': serializer.toJson<String?>(albumName),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'discNumber': serializer.toJson<int?>(discNumber),
      'durationMicros': serializer.toJson<int?>(durationMicros),
      'normalizationGain': serializer.toJson<double?>(normalizationGain),
      'imageItemId': serializer.toJson<String?>(imageItemId),
      'imageKind': serializer.toJson<String?>(imageKind),
      'imageTag': serializer.toJson<String?>(imageTag),
      'imageAspectRatio': serializer.toJson<double?>(imageAspectRatio),
      'requestedAt': serializer.toJson<int>(requestedAt),
    };
  }

  TrackDownloadRow copyWith({
    String? accountKey,
    String? serverId,
    String? itemId,
    String? state,
    bool? serverGone,
    Value<String?> failureReason = const Value.absent(),
    int? receivedBytes,
    Value<int?> totalBytes = const Value.absent(),
    String? title,
    Value<String?> artistsJson = const Value.absent(),
    Value<String?> albumItemId = const Value.absent(),
    Value<String?> albumName = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> durationMicros = const Value.absent(),
    Value<double?> normalizationGain = const Value.absent(),
    Value<String?> imageItemId = const Value.absent(),
    Value<String?> imageKind = const Value.absent(),
    Value<String?> imageTag = const Value.absent(),
    Value<double?> imageAspectRatio = const Value.absent(),
    int? requestedAt,
  }) => TrackDownloadRow(
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId ?? this.serverId,
    itemId: itemId ?? this.itemId,
    state: state ?? this.state,
    serverGone: serverGone ?? this.serverGone,
    failureReason: failureReason.present
        ? failureReason.value
        : this.failureReason,
    receivedBytes: receivedBytes ?? this.receivedBytes,
    totalBytes: totalBytes.present ? totalBytes.value : this.totalBytes,
    title: title ?? this.title,
    artistsJson: artistsJson.present ? artistsJson.value : this.artistsJson,
    albumItemId: albumItemId.present ? albumItemId.value : this.albumItemId,
    albumName: albumName.present ? albumName.value : this.albumName,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    durationMicros: durationMicros.present
        ? durationMicros.value
        : this.durationMicros,
    normalizationGain: normalizationGain.present
        ? normalizationGain.value
        : this.normalizationGain,
    imageItemId: imageItemId.present ? imageItemId.value : this.imageItemId,
    imageKind: imageKind.present ? imageKind.value : this.imageKind,
    imageTag: imageTag.present ? imageTag.value : this.imageTag,
    imageAspectRatio: imageAspectRatio.present
        ? imageAspectRatio.value
        : this.imageAspectRatio,
    requestedAt: requestedAt ?? this.requestedAt,
  );
  TrackDownloadRow copyWithCompanion(TrackDownloadsCompanion data) {
    return TrackDownloadRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      state: data.state.present ? data.state.value : this.state,
      serverGone: data.serverGone.present
          ? data.serverGone.value
          : this.serverGone,
      failureReason: data.failureReason.present
          ? data.failureReason.value
          : this.failureReason,
      receivedBytes: data.receivedBytes.present
          ? data.receivedBytes.value
          : this.receivedBytes,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      title: data.title.present ? data.title.value : this.title,
      artistsJson: data.artistsJson.present
          ? data.artistsJson.value
          : this.artistsJson,
      albumItemId: data.albumItemId.present
          ? data.albumItemId.value
          : this.albumItemId,
      albumName: data.albumName.present ? data.albumName.value : this.albumName,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      durationMicros: data.durationMicros.present
          ? data.durationMicros.value
          : this.durationMicros,
      normalizationGain: data.normalizationGain.present
          ? data.normalizationGain.value
          : this.normalizationGain,
      imageItemId: data.imageItemId.present
          ? data.imageItemId.value
          : this.imageItemId,
      imageKind: data.imageKind.present ? data.imageKind.value : this.imageKind,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      imageAspectRatio: data.imageAspectRatio.present
          ? data.imageAspectRatio.value
          : this.imageAspectRatio,
      requestedAt: data.requestedAt.present
          ? data.requestedAt.value
          : this.requestedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackDownloadRow(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('state: $state, ')
          ..write('serverGone: $serverGone, ')
          ..write('failureReason: $failureReason, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('title: $title, ')
          ..write('artistsJson: $artistsJson, ')
          ..write('albumItemId: $albumItemId, ')
          ..write('albumName: $albumName, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMicros: $durationMicros, ')
          ..write('normalizationGain: $normalizationGain, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('requestedAt: $requestedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    accountKey,
    serverId,
    itemId,
    state,
    serverGone,
    failureReason,
    receivedBytes,
    totalBytes,
    title,
    artistsJson,
    albumItemId,
    albumName,
    trackNumber,
    discNumber,
    durationMicros,
    normalizationGain,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    requestedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackDownloadRow &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.itemId == this.itemId &&
          other.state == this.state &&
          other.serverGone == this.serverGone &&
          other.failureReason == this.failureReason &&
          other.receivedBytes == this.receivedBytes &&
          other.totalBytes == this.totalBytes &&
          other.title == this.title &&
          other.artistsJson == this.artistsJson &&
          other.albumItemId == this.albumItemId &&
          other.albumName == this.albumName &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.durationMicros == this.durationMicros &&
          other.normalizationGain == this.normalizationGain &&
          other.imageItemId == this.imageItemId &&
          other.imageKind == this.imageKind &&
          other.imageTag == this.imageTag &&
          other.imageAspectRatio == this.imageAspectRatio &&
          other.requestedAt == this.requestedAt);
}

class TrackDownloadsCompanion extends UpdateCompanion<TrackDownloadRow> {
  final Value<String> accountKey;
  final Value<String> serverId;
  final Value<String> itemId;
  final Value<String> state;
  final Value<bool> serverGone;
  final Value<String?> failureReason;
  final Value<int> receivedBytes;
  final Value<int?> totalBytes;
  final Value<String> title;
  final Value<String?> artistsJson;
  final Value<String?> albumItemId;
  final Value<String?> albumName;
  final Value<int?> trackNumber;
  final Value<int?> discNumber;
  final Value<int?> durationMicros;
  final Value<double?> normalizationGain;
  final Value<String?> imageItemId;
  final Value<String?> imageKind;
  final Value<String?> imageTag;
  final Value<double?> imageAspectRatio;
  final Value<int> requestedAt;
  final Value<int> rowid;
  const TrackDownloadsCompanion({
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.state = const Value.absent(),
    this.serverGone = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.title = const Value.absent(),
    this.artistsJson = const Value.absent(),
    this.albumItemId = const Value.absent(),
    this.albumName = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMicros = const Value.absent(),
    this.normalizationGain = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackDownloadsCompanion.insert({
    this.accountKey = const Value.absent(),
    required String serverId,
    required String itemId,
    required String state,
    this.serverGone = const Value.absent(),
    this.failureReason = const Value.absent(),
    this.receivedBytes = const Value.absent(),
    this.totalBytes = const Value.absent(),
    required String title,
    this.artistsJson = const Value.absent(),
    this.albumItemId = const Value.absent(),
    this.albumName = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMicros = const Value.absent(),
    this.normalizationGain = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    required int requestedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       itemId = Value(itemId),
       state = Value(state),
       title = Value(title),
       requestedAt = Value(requestedAt);
  static Insertable<TrackDownloadRow> custom({
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? itemId,
    Expression<String>? state,
    Expression<bool>? serverGone,
    Expression<String>? failureReason,
    Expression<int>? receivedBytes,
    Expression<int>? totalBytes,
    Expression<String>? title,
    Expression<String>? artistsJson,
    Expression<String>? albumItemId,
    Expression<String>? albumName,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? durationMicros,
    Expression<double>? normalizationGain,
    Expression<String>? imageItemId,
    Expression<String>? imageKind,
    Expression<String>? imageTag,
    Expression<double>? imageAspectRatio,
    Expression<int>? requestedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (itemId != null) 'item_id': itemId,
      if (state != null) 'state': state,
      if (serverGone != null) 'server_gone': serverGone,
      if (failureReason != null) 'failure_reason': failureReason,
      if (receivedBytes != null) 'received_bytes': receivedBytes,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (title != null) 'title': title,
      if (artistsJson != null) 'artists_json': artistsJson,
      if (albumItemId != null) 'album_item_id': albumItemId,
      if (albumName != null) 'album_name': albumName,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (durationMicros != null) 'duration_micros': durationMicros,
      if (normalizationGain != null) 'normalization_gain': normalizationGain,
      if (imageItemId != null) 'image_item_id': imageItemId,
      if (imageKind != null) 'image_kind': imageKind,
      if (imageTag != null) 'image_tag': imageTag,
      if (imageAspectRatio != null) 'image_aspect_ratio': imageAspectRatio,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackDownloadsCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? serverId,
    Value<String>? itemId,
    Value<String>? state,
    Value<bool>? serverGone,
    Value<String?>? failureReason,
    Value<int>? receivedBytes,
    Value<int?>? totalBytes,
    Value<String>? title,
    Value<String?>? artistsJson,
    Value<String?>? albumItemId,
    Value<String?>? albumName,
    Value<int?>? trackNumber,
    Value<int?>? discNumber,
    Value<int?>? durationMicros,
    Value<double?>? normalizationGain,
    Value<String?>? imageItemId,
    Value<String?>? imageKind,
    Value<String?>? imageTag,
    Value<double?>? imageAspectRatio,
    Value<int>? requestedAt,
    Value<int>? rowid,
  }) {
    return TrackDownloadsCompanion(
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      itemId: itemId ?? this.itemId,
      state: state ?? this.state,
      serverGone: serverGone ?? this.serverGone,
      failureReason: failureReason ?? this.failureReason,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      title: title ?? this.title,
      artistsJson: artistsJson ?? this.artistsJson,
      albumItemId: albumItemId ?? this.albumItemId,
      albumName: albumName ?? this.albumName,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMicros: durationMicros ?? this.durationMicros,
      normalizationGain: normalizationGain ?? this.normalizationGain,
      imageItemId: imageItemId ?? this.imageItemId,
      imageKind: imageKind ?? this.imageKind,
      imageTag: imageTag ?? this.imageTag,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      requestedAt: requestedAt ?? this.requestedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (serverGone.present) {
      map['server_gone'] = Variable<bool>(serverGone.value);
    }
    if (failureReason.present) {
      map['failure_reason'] = Variable<String>(failureReason.value);
    }
    if (receivedBytes.present) {
      map['received_bytes'] = Variable<int>(receivedBytes.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artistsJson.present) {
      map['artists_json'] = Variable<String>(artistsJson.value);
    }
    if (albumItemId.present) {
      map['album_item_id'] = Variable<String>(albumItemId.value);
    }
    if (albumName.present) {
      map['album_name'] = Variable<String>(albumName.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (durationMicros.present) {
      map['duration_micros'] = Variable<int>(durationMicros.value);
    }
    if (normalizationGain.present) {
      map['normalization_gain'] = Variable<double>(normalizationGain.value);
    }
    if (imageItemId.present) {
      map['image_item_id'] = Variable<String>(imageItemId.value);
    }
    if (imageKind.present) {
      map['image_kind'] = Variable<String>(imageKind.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (imageAspectRatio.present) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<int>(requestedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackDownloadsCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('state: $state, ')
          ..write('serverGone: $serverGone, ')
          ..write('failureReason: $failureReason, ')
          ..write('receivedBytes: $receivedBytes, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('title: $title, ')
          ..write('artistsJson: $artistsJson, ')
          ..write('albumItemId: $albumItemId, ')
          ..write('albumName: $albumName, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMicros: $durationMicros, ')
          ..write('normalizationGain: $normalizationGain, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadOwnersTable extends DownloadOwners
    with TableInfo<$DownloadOwnersTable, DownloadOwnerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadOwnersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerKindMeta = const VerificationMeta(
    'ownerKind',
  );
  @override
  late final GeneratedColumn<String> ownerKind = GeneratedColumn<String>(
    'owner_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerItemIdMeta = const VerificationMeta(
    'ownerItemId',
  );
  @override
  late final GeneratedColumn<String> ownerItemId = GeneratedColumn<String>(
    'owner_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    serverId,
    itemId,
    ownerKind,
    ownerItemId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_owners';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadOwnerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('owner_kind')) {
      context.handle(
        _ownerKindMeta,
        ownerKind.isAcceptableOrUnknown(data['owner_kind']!, _ownerKindMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerKindMeta);
    }
    if (data.containsKey('owner_item_id')) {
      context.handle(
        _ownerItemIdMeta,
        ownerItemId.isAcceptableOrUnknown(
          data['owner_item_id']!,
          _ownerItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerItemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountKey,
    serverId,
    itemId,
    ownerKind,
    ownerItemId,
  };
  @override
  DownloadOwnerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadOwnerRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      ownerKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_kind'],
      )!,
      ownerItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_item_id'],
      )!,
    );
  }

  @override
  $DownloadOwnersTable createAlias(String alias) {
    return $DownloadOwnersTable(attachedDatabase, alias);
  }
}

class DownloadOwnerRow extends DataClass
    implements Insertable<DownloadOwnerRow> {
  /// The profile whose download this reason belongs to (v0.2.3), matching
  /// the [TrackDownloads] row it counts against. Reference counting is
  /// per-profile: removing one profile's album never drops a claim
  /// another profile's download holds.
  final String accountKey;
  final String serverId;

  /// The downloaded track's item id.
  final String itemId;

  /// `DownloadOwnerKind.name` — `track`, `album`, (v0.2.1) `playlist` or
  /// (v0.2.2) `artist`.
  final String ownerKind;

  /// The owning item's id on the same server (the track's own id for a
  /// `track` owner, the album's for an `album` owner, the playlist's for
  /// a `playlist` owner).
  final String ownerItemId;
  const DownloadOwnerRow({
    required this.accountKey,
    required this.serverId,
    required this.itemId,
    required this.ownerKind,
    required this.ownerItemId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['server_id'] = Variable<String>(serverId);
    map['item_id'] = Variable<String>(itemId);
    map['owner_kind'] = Variable<String>(ownerKind);
    map['owner_item_id'] = Variable<String>(ownerItemId);
    return map;
  }

  DownloadOwnersCompanion toCompanion(bool nullToAbsent) {
    return DownloadOwnersCompanion(
      accountKey: Value(accountKey),
      serverId: Value(serverId),
      itemId: Value(itemId),
      ownerKind: Value(ownerKind),
      ownerItemId: Value(ownerItemId),
    );
  }

  factory DownloadOwnerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadOwnerRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String>(json['serverId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      ownerKind: serializer.fromJson<String>(json['ownerKind']),
      ownerItemId: serializer.fromJson<String>(json['ownerItemId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String>(serverId),
      'itemId': serializer.toJson<String>(itemId),
      'ownerKind': serializer.toJson<String>(ownerKind),
      'ownerItemId': serializer.toJson<String>(ownerItemId),
    };
  }

  DownloadOwnerRow copyWith({
    String? accountKey,
    String? serverId,
    String? itemId,
    String? ownerKind,
    String? ownerItemId,
  }) => DownloadOwnerRow(
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId ?? this.serverId,
    itemId: itemId ?? this.itemId,
    ownerKind: ownerKind ?? this.ownerKind,
    ownerItemId: ownerItemId ?? this.ownerItemId,
  );
  DownloadOwnerRow copyWithCompanion(DownloadOwnersCompanion data) {
    return DownloadOwnerRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      ownerKind: data.ownerKind.present ? data.ownerKind.value : this.ownerKind,
      ownerItemId: data.ownerItemId.present
          ? data.ownerItemId.value
          : this.ownerItemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadOwnerRow(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('ownerKind: $ownerKind, ')
          ..write('ownerItemId: $ownerItemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountKey, serverId, itemId, ownerKind, ownerItemId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadOwnerRow &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.itemId == this.itemId &&
          other.ownerKind == this.ownerKind &&
          other.ownerItemId == this.ownerItemId);
}

class DownloadOwnersCompanion extends UpdateCompanion<DownloadOwnerRow> {
  final Value<String> accountKey;
  final Value<String> serverId;
  final Value<String> itemId;
  final Value<String> ownerKind;
  final Value<String> ownerItemId;
  final Value<int> rowid;
  const DownloadOwnersCompanion({
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.ownerKind = const Value.absent(),
    this.ownerItemId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadOwnersCompanion.insert({
    this.accountKey = const Value.absent(),
    required String serverId,
    required String itemId,
    required String ownerKind,
    required String ownerItemId,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       itemId = Value(itemId),
       ownerKind = Value(ownerKind),
       ownerItemId = Value(ownerItemId);
  static Insertable<DownloadOwnerRow> custom({
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? itemId,
    Expression<String>? ownerKind,
    Expression<String>? ownerItemId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (itemId != null) 'item_id': itemId,
      if (ownerKind != null) 'owner_kind': ownerKind,
      if (ownerItemId != null) 'owner_item_id': ownerItemId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadOwnersCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? serverId,
    Value<String>? itemId,
    Value<String>? ownerKind,
    Value<String>? ownerItemId,
    Value<int>? rowid,
  }) {
    return DownloadOwnersCompanion(
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      itemId: itemId ?? this.itemId,
      ownerKind: ownerKind ?? this.ownerKind,
      ownerItemId: ownerItemId ?? this.ownerItemId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (ownerKind.present) {
      map['owner_kind'] = Variable<String>(ownerKind.value);
    }
    if (ownerItemId.present) {
      map['owner_item_id'] = Variable<String>(ownerItemId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadOwnersCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('ownerKind: $ownerKind, ')
          ..write('ownerItemId: $ownerItemId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistDownloadMembersTable extends PlaylistDownloadMembers
    with TableInfo<$PlaylistDownloadMembersTable, PlaylistDownloadMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistDownloadMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playlistItemIdMeta = const VerificationMeta(
    'playlistItemId',
  );
  @override
  late final GeneratedColumn<String> playlistItemId = GeneratedColumn<String>(
    'playlist_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackItemIdMeta = const VerificationMeta(
    'trackItemId',
  );
  @override
  late final GeneratedColumn<String> trackItemId = GeneratedColumn<String>(
    'track_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    serverId,
    playlistItemId,
    position,
    trackItemId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_download_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistDownloadMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('playlist_item_id')) {
      context.handle(
        _playlistItemIdMeta,
        playlistItemId.isAcceptableOrUnknown(
          data['playlist_item_id']!,
          _playlistItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playlistItemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('track_item_id')) {
      context.handle(
        _trackItemIdMeta,
        trackItemId.isAcceptableOrUnknown(
          data['track_item_id']!,
          _trackItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackItemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountKey,
    serverId,
    playlistItemId,
    position,
  };
  @override
  PlaylistDownloadMemberRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistDownloadMemberRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      playlistItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playlist_item_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      trackItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_item_id'],
      )!,
    );
  }

  @override
  $PlaylistDownloadMembersTable createAlias(String alias) {
    return $PlaylistDownloadMembersTable(attachedDatabase, alias);
  }
}

class PlaylistDownloadMemberRow extends DataClass
    implements Insertable<PlaylistDownloadMemberRow> {
  /// The profile whose playlist download this snapshot belongs to
  /// (v0.2.3), matching the [TrackDownloads] rows it orders.
  final String accountKey;
  final String serverId;

  /// The downloaded playlist's own item id.
  final String playlistItemId;

  /// The member's index among the playlist's downloadable tracks, in the
  /// playlist's own order.
  final int position;

  /// The track at that position — a [TrackDownloads] row key on the same
  /// server.
  final String trackItemId;
  const PlaylistDownloadMemberRow({
    required this.accountKey,
    required this.serverId,
    required this.playlistItemId,
    required this.position,
    required this.trackItemId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['server_id'] = Variable<String>(serverId);
    map['playlist_item_id'] = Variable<String>(playlistItemId);
    map['position'] = Variable<int>(position);
    map['track_item_id'] = Variable<String>(trackItemId);
    return map;
  }

  PlaylistDownloadMembersCompanion toCompanion(bool nullToAbsent) {
    return PlaylistDownloadMembersCompanion(
      accountKey: Value(accountKey),
      serverId: Value(serverId),
      playlistItemId: Value(playlistItemId),
      position: Value(position),
      trackItemId: Value(trackItemId),
    );
  }

  factory PlaylistDownloadMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistDownloadMemberRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String>(json['serverId']),
      playlistItemId: serializer.fromJson<String>(json['playlistItemId']),
      position: serializer.fromJson<int>(json['position']),
      trackItemId: serializer.fromJson<String>(json['trackItemId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String>(serverId),
      'playlistItemId': serializer.toJson<String>(playlistItemId),
      'position': serializer.toJson<int>(position),
      'trackItemId': serializer.toJson<String>(trackItemId),
    };
  }

  PlaylistDownloadMemberRow copyWith({
    String? accountKey,
    String? serverId,
    String? playlistItemId,
    int? position,
    String? trackItemId,
  }) => PlaylistDownloadMemberRow(
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId ?? this.serverId,
    playlistItemId: playlistItemId ?? this.playlistItemId,
    position: position ?? this.position,
    trackItemId: trackItemId ?? this.trackItemId,
  );
  PlaylistDownloadMemberRow copyWithCompanion(
    PlaylistDownloadMembersCompanion data,
  ) {
    return PlaylistDownloadMemberRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      playlistItemId: data.playlistItemId.present
          ? data.playlistItemId.value
          : this.playlistItemId,
      position: data.position.present ? data.position.value : this.position,
      trackItemId: data.trackItemId.present
          ? data.trackItemId.value
          : this.trackItemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistDownloadMemberRow(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('playlistItemId: $playlistItemId, ')
          ..write('position: $position, ')
          ..write('trackItemId: $trackItemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountKey, serverId, playlistItemId, position, trackItemId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistDownloadMemberRow &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.playlistItemId == this.playlistItemId &&
          other.position == this.position &&
          other.trackItemId == this.trackItemId);
}

class PlaylistDownloadMembersCompanion
    extends UpdateCompanion<PlaylistDownloadMemberRow> {
  final Value<String> accountKey;
  final Value<String> serverId;
  final Value<String> playlistItemId;
  final Value<int> position;
  final Value<String> trackItemId;
  final Value<int> rowid;
  const PlaylistDownloadMembersCompanion({
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.playlistItemId = const Value.absent(),
    this.position = const Value.absent(),
    this.trackItemId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistDownloadMembersCompanion.insert({
    this.accountKey = const Value.absent(),
    required String serverId,
    required String playlistItemId,
    required int position,
    required String trackItemId,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       playlistItemId = Value(playlistItemId),
       position = Value(position),
       trackItemId = Value(trackItemId);
  static Insertable<PlaylistDownloadMemberRow> custom({
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? playlistItemId,
    Expression<int>? position,
    Expression<String>? trackItemId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (playlistItemId != null) 'playlist_item_id': playlistItemId,
      if (position != null) 'position': position,
      if (trackItemId != null) 'track_item_id': trackItemId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistDownloadMembersCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? serverId,
    Value<String>? playlistItemId,
    Value<int>? position,
    Value<String>? trackItemId,
    Value<int>? rowid,
  }) {
    return PlaylistDownloadMembersCompanion(
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      playlistItemId: playlistItemId ?? this.playlistItemId,
      position: position ?? this.position,
      trackItemId: trackItemId ?? this.trackItemId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (playlistItemId.present) {
      map['playlist_item_id'] = Variable<String>(playlistItemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (trackItemId.present) {
      map['track_item_id'] = Variable<String>(trackItemId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistDownloadMembersCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('playlistItemId: $playlistItemId, ')
          ..write('position: $position, ')
          ..write('trackItemId: $trackItemId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadedCollectionsTable extends DownloadedCollections
    with TableInfo<$DownloadedCollectionsTable, DownloadedCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerKindMeta = const VerificationMeta(
    'ownerKind',
  );
  @override
  late final GeneratedColumn<String> ownerKind = GeneratedColumn<String>(
    'owner_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerItemIdMeta = const VerificationMeta(
    'ownerItemId',
  );
  @override
  late final GeneratedColumn<String> ownerItemId = GeneratedColumn<String>(
    'owner_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortNameMeta = const VerificationMeta(
    'sortName',
  );
  @override
  late final GeneratedColumn<String> sortName = GeneratedColumn<String>(
    'sort_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageItemIdMeta = const VerificationMeta(
    'imageItemId',
  );
  @override
  late final GeneratedColumn<String> imageItemId = GeneratedColumn<String>(
    'image_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageKindMeta = const VerificationMeta(
    'imageKind',
  );
  @override
  late final GeneratedColumn<String> imageKind = GeneratedColumn<String>(
    'image_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageAspectRatioMeta = const VerificationMeta(
    'imageAspectRatio',
  );
  @override
  late final GeneratedColumn<double> imageAspectRatio = GeneratedColumn<double>(
    'image_aspect_ratio',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    serverId,
    ownerKind,
    ownerItemId,
    name,
    sortName,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadedCollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('owner_kind')) {
      context.handle(
        _ownerKindMeta,
        ownerKind.isAcceptableOrUnknown(data['owner_kind']!, _ownerKindMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerKindMeta);
    }
    if (data.containsKey('owner_item_id')) {
      context.handle(
        _ownerItemIdMeta,
        ownerItemId.isAcceptableOrUnknown(
          data['owner_item_id']!,
          _ownerItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerItemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_name')) {
      context.handle(
        _sortNameMeta,
        sortName.isAcceptableOrUnknown(data['sort_name']!, _sortNameMeta),
      );
    }
    if (data.containsKey('image_item_id')) {
      context.handle(
        _imageItemIdMeta,
        imageItemId.isAcceptableOrUnknown(
          data['image_item_id']!,
          _imageItemIdMeta,
        ),
      );
    }
    if (data.containsKey('image_kind')) {
      context.handle(
        _imageKindMeta,
        imageKind.isAcceptableOrUnknown(data['image_kind']!, _imageKindMeta),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    }
    if (data.containsKey('image_aspect_ratio')) {
      context.handle(
        _imageAspectRatioMeta,
        imageAspectRatio.isAcceptableOrUnknown(
          data['image_aspect_ratio']!,
          _imageAspectRatioMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountKey,
    serverId,
    ownerKind,
    ownerItemId,
  };
  @override
  DownloadedCollectionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedCollectionRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      ownerKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_kind'],
      )!,
      ownerItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_item_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort_name'],
      )!,
      imageItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_item_id'],
      ),
      imageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_kind'],
      ),
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      ),
      imageAspectRatio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}image_aspect_ratio'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DownloadedCollectionsTable createAlias(String alias) {
    return $DownloadedCollectionsTable(attachedDatabase, alias);
  }
}

class DownloadedCollectionRow extends DataClass
    implements Insertable<DownloadedCollectionRow> {
  final String accountKey;
  final String serverId;

  /// `DownloadOwnerKind.name` — `album`, `artist` or `playlist`. Never
  /// `track`: a standalone track is its own [TrackDownloads] record.
  final String ownerKind;
  final String ownerItemId;
  final String name;

  /// The lowercased name, so an offline listing orders and a search
  /// matches without a `lower()` over every row of a scan.
  final String sortName;

  /// Artwork pointer, flattened the same way [CachedMediaItems] flattens
  /// it. Rendered offline from the artwork disk cache where it was seen
  /// online; missing art falls back to the placeholder.
  final String? imageItemId;
  final String? imageKind;
  final String? imageTag;
  final double? imageAspectRatio;
  final int updatedAt;
  const DownloadedCollectionRow({
    required this.accountKey,
    required this.serverId,
    required this.ownerKind,
    required this.ownerItemId,
    required this.name,
    required this.sortName,
    this.imageItemId,
    this.imageKind,
    this.imageTag,
    this.imageAspectRatio,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['server_id'] = Variable<String>(serverId);
    map['owner_kind'] = Variable<String>(ownerKind);
    map['owner_item_id'] = Variable<String>(ownerItemId);
    map['name'] = Variable<String>(name);
    map['sort_name'] = Variable<String>(sortName);
    if (!nullToAbsent || imageItemId != null) {
      map['image_item_id'] = Variable<String>(imageItemId);
    }
    if (!nullToAbsent || imageKind != null) {
      map['image_kind'] = Variable<String>(imageKind);
    }
    if (!nullToAbsent || imageTag != null) {
      map['image_tag'] = Variable<String>(imageTag);
    }
    if (!nullToAbsent || imageAspectRatio != null) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  DownloadedCollectionsCompanion toCompanion(bool nullToAbsent) {
    return DownloadedCollectionsCompanion(
      accountKey: Value(accountKey),
      serverId: Value(serverId),
      ownerKind: Value(ownerKind),
      ownerItemId: Value(ownerItemId),
      name: Value(name),
      sortName: Value(sortName),
      imageItemId: imageItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageItemId),
      imageKind: imageKind == null && nullToAbsent
          ? const Value.absent()
          : Value(imageKind),
      imageTag: imageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(imageTag),
      imageAspectRatio: imageAspectRatio == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAspectRatio),
      updatedAt: Value(updatedAt),
    );
  }

  factory DownloadedCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedCollectionRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      serverId: serializer.fromJson<String>(json['serverId']),
      ownerKind: serializer.fromJson<String>(json['ownerKind']),
      ownerItemId: serializer.fromJson<String>(json['ownerItemId']),
      name: serializer.fromJson<String>(json['name']),
      sortName: serializer.fromJson<String>(json['sortName']),
      imageItemId: serializer.fromJson<String?>(json['imageItemId']),
      imageKind: serializer.fromJson<String?>(json['imageKind']),
      imageTag: serializer.fromJson<String?>(json['imageTag']),
      imageAspectRatio: serializer.fromJson<double?>(json['imageAspectRatio']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'serverId': serializer.toJson<String>(serverId),
      'ownerKind': serializer.toJson<String>(ownerKind),
      'ownerItemId': serializer.toJson<String>(ownerItemId),
      'name': serializer.toJson<String>(name),
      'sortName': serializer.toJson<String>(sortName),
      'imageItemId': serializer.toJson<String?>(imageItemId),
      'imageKind': serializer.toJson<String?>(imageKind),
      'imageTag': serializer.toJson<String?>(imageTag),
      'imageAspectRatio': serializer.toJson<double?>(imageAspectRatio),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  DownloadedCollectionRow copyWith({
    String? accountKey,
    String? serverId,
    String? ownerKind,
    String? ownerItemId,
    String? name,
    String? sortName,
    Value<String?> imageItemId = const Value.absent(),
    Value<String?> imageKind = const Value.absent(),
    Value<String?> imageTag = const Value.absent(),
    Value<double?> imageAspectRatio = const Value.absent(),
    int? updatedAt,
  }) => DownloadedCollectionRow(
    accountKey: accountKey ?? this.accountKey,
    serverId: serverId ?? this.serverId,
    ownerKind: ownerKind ?? this.ownerKind,
    ownerItemId: ownerItemId ?? this.ownerItemId,
    name: name ?? this.name,
    sortName: sortName ?? this.sortName,
    imageItemId: imageItemId.present ? imageItemId.value : this.imageItemId,
    imageKind: imageKind.present ? imageKind.value : this.imageKind,
    imageTag: imageTag.present ? imageTag.value : this.imageTag,
    imageAspectRatio: imageAspectRatio.present
        ? imageAspectRatio.value
        : this.imageAspectRatio,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DownloadedCollectionRow copyWithCompanion(
    DownloadedCollectionsCompanion data,
  ) {
    return DownloadedCollectionRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      ownerKind: data.ownerKind.present ? data.ownerKind.value : this.ownerKind,
      ownerItemId: data.ownerItemId.present
          ? data.ownerItemId.value
          : this.ownerItemId,
      name: data.name.present ? data.name.value : this.name,
      sortName: data.sortName.present ? data.sortName.value : this.sortName,
      imageItemId: data.imageItemId.present
          ? data.imageItemId.value
          : this.imageItemId,
      imageKind: data.imageKind.present ? data.imageKind.value : this.imageKind,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      imageAspectRatio: data.imageAspectRatio.present
          ? data.imageAspectRatio.value
          : this.imageAspectRatio,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedCollectionRow(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('ownerKind: $ownerKind, ')
          ..write('ownerItemId: $ownerItemId, ')
          ..write('name: $name, ')
          ..write('sortName: $sortName, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountKey,
    serverId,
    ownerKind,
    ownerItemId,
    name,
    sortName,
    imageItemId,
    imageKind,
    imageTag,
    imageAspectRatio,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedCollectionRow &&
          other.accountKey == this.accountKey &&
          other.serverId == this.serverId &&
          other.ownerKind == this.ownerKind &&
          other.ownerItemId == this.ownerItemId &&
          other.name == this.name &&
          other.sortName == this.sortName &&
          other.imageItemId == this.imageItemId &&
          other.imageKind == this.imageKind &&
          other.imageTag == this.imageTag &&
          other.imageAspectRatio == this.imageAspectRatio &&
          other.updatedAt == this.updatedAt);
}

class DownloadedCollectionsCompanion
    extends UpdateCompanion<DownloadedCollectionRow> {
  final Value<String> accountKey;
  final Value<String> serverId;
  final Value<String> ownerKind;
  final Value<String> ownerItemId;
  final Value<String> name;
  final Value<String> sortName;
  final Value<String?> imageItemId;
  final Value<String?> imageKind;
  final Value<String?> imageTag;
  final Value<double?> imageAspectRatio;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const DownloadedCollectionsCompanion({
    this.accountKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.ownerKind = const Value.absent(),
    this.ownerItemId = const Value.absent(),
    this.name = const Value.absent(),
    this.sortName = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadedCollectionsCompanion.insert({
    this.accountKey = const Value.absent(),
    required String serverId,
    required String ownerKind,
    required String ownerItemId,
    required String name,
    this.sortName = const Value.absent(),
    this.imageItemId = const Value.absent(),
    this.imageKind = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.imageAspectRatio = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       ownerKind = Value(ownerKind),
       ownerItemId = Value(ownerItemId),
       name = Value(name),
       updatedAt = Value(updatedAt);
  static Insertable<DownloadedCollectionRow> custom({
    Expression<String>? accountKey,
    Expression<String>? serverId,
    Expression<String>? ownerKind,
    Expression<String>? ownerItemId,
    Expression<String>? name,
    Expression<String>? sortName,
    Expression<String>? imageItemId,
    Expression<String>? imageKind,
    Expression<String>? imageTag,
    Expression<double>? imageAspectRatio,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (serverId != null) 'server_id': serverId,
      if (ownerKind != null) 'owner_kind': ownerKind,
      if (ownerItemId != null) 'owner_item_id': ownerItemId,
      if (name != null) 'name': name,
      if (sortName != null) 'sort_name': sortName,
      if (imageItemId != null) 'image_item_id': imageItemId,
      if (imageKind != null) 'image_kind': imageKind,
      if (imageTag != null) 'image_tag': imageTag,
      if (imageAspectRatio != null) 'image_aspect_ratio': imageAspectRatio,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadedCollectionsCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? serverId,
    Value<String>? ownerKind,
    Value<String>? ownerItemId,
    Value<String>? name,
    Value<String>? sortName,
    Value<String?>? imageItemId,
    Value<String?>? imageKind,
    Value<String?>? imageTag,
    Value<double?>? imageAspectRatio,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return DownloadedCollectionsCompanion(
      accountKey: accountKey ?? this.accountKey,
      serverId: serverId ?? this.serverId,
      ownerKind: ownerKind ?? this.ownerKind,
      ownerItemId: ownerItemId ?? this.ownerItemId,
      name: name ?? this.name,
      sortName: sortName ?? this.sortName,
      imageItemId: imageItemId ?? this.imageItemId,
      imageKind: imageKind ?? this.imageKind,
      imageTag: imageTag ?? this.imageTag,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (ownerKind.present) {
      map['owner_kind'] = Variable<String>(ownerKind.value);
    }
    if (ownerItemId.present) {
      map['owner_item_id'] = Variable<String>(ownerItemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortName.present) {
      map['sort_name'] = Variable<String>(sortName.value);
    }
    if (imageItemId.present) {
      map['image_item_id'] = Variable<String>(imageItemId.value);
    }
    if (imageKind.present) {
      map['image_kind'] = Variable<String>(imageKind.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (imageAspectRatio.present) {
      map['image_aspect_ratio'] = Variable<double>(imageAspectRatio.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedCollectionsCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('serverId: $serverId, ')
          ..write('ownerKind: $ownerKind, ')
          ..write('ownerItemId: $ownerItemId, ')
          ..write('name: $name, ')
          ..write('sortName: $sortName, ')
          ..write('imageItemId: $imageItemId, ')
          ..write('imageKind: $imageKind, ')
          ..write('imageTag: $imageTag, ')
          ..write('imageAspectRatio: $imageAspectRatio, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SavedServersTable savedServers = $SavedServersTable(this);
  late final $SavedAccountsTable savedAccounts = $SavedAccountsTable(this);
  late final $KeyValueEntriesTable keyValueEntries = $KeyValueEntriesTable(
    this,
  );
  late final $CachedMediaItemsTable cachedMediaItems = $CachedMediaItemsTable(
    this,
  );
  late final $CachedCollectionsTable cachedCollections =
      $CachedCollectionsTable(this);
  late final $CachedCollectionEntriesTable cachedCollectionEntries =
      $CachedCollectionEntriesTable(this);
  late final $QueueEntriesTable queueEntries = $QueueEntriesTable(this);
  late final $TrackDownloadsTable trackDownloads = $TrackDownloadsTable(this);
  late final $DownloadOwnersTable downloadOwners = $DownloadOwnersTable(this);
  late final $PlaylistDownloadMembersTable playlistDownloadMembers =
      $PlaylistDownloadMembersTable(this);
  late final $DownloadedCollectionsTable downloadedCollections =
      $DownloadedCollectionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    savedServers,
    savedAccounts,
    keyValueEntries,
    cachedMediaItems,
    cachedCollections,
    cachedCollectionEntries,
    queueEntries,
    trackDownloads,
    downloadOwners,
    playlistDownloadMembers,
    downloadedCollections,
  ];
}

typedef $$SavedServersTableCreateCompanionBuilder =
    SavedServersCompanion Function({
      required String id,
      required String baseUrl,
      required String name,
      Value<String> reportedVersion,
      Value<String?> serverId,
      required int addedAt,
      Value<int> rowid,
    });
typedef $$SavedServersTableUpdateCompanionBuilder =
    SavedServersCompanion Function({
      Value<String> id,
      Value<String> baseUrl,
      Value<String> name,
      Value<String> reportedVersion,
      Value<String?> serverId,
      Value<int> addedAt,
      Value<int> rowid,
    });

class $$SavedServersTableFilterComposer
    extends Composer<_$AppDatabase, $SavedServersTable> {
  $$SavedServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reportedVersion => $composableBuilder(
    column: $table.reportedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedServersTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedServersTable> {
  $$SavedServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reportedVersion => $composableBuilder(
    column: $table.reportedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedServersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedServersTable> {
  $$SavedServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get reportedVersion => $composableBuilder(
    column: $table.reportedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$SavedServersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedServersTable,
          SavedServerRow,
          $$SavedServersTableFilterComposer,
          $$SavedServersTableOrderingComposer,
          $$SavedServersTableAnnotationComposer,
          $$SavedServersTableCreateCompanionBuilder,
          $$SavedServersTableUpdateCompanionBuilder,
          (
            SavedServerRow,
            BaseReferences<_$AppDatabase, $SavedServersTable, SavedServerRow>,
          ),
          SavedServerRow,
          PrefetchHooks Function()
        > {
  $$SavedServersTableTableManager(_$AppDatabase db, $SavedServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> reportedVersion = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedServersCompanion(
                id: id,
                baseUrl: baseUrl,
                name: name,
                reportedVersion: reportedVersion,
                serverId: serverId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String baseUrl,
                required String name,
                Value<String> reportedVersion = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                required int addedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedServersCompanion.insert(
                id: id,
                baseUrl: baseUrl,
                name: name,
                reportedVersion: reportedVersion,
                serverId: serverId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedServersTable,
      SavedServerRow,
      $$SavedServersTableFilterComposer,
      $$SavedServersTableOrderingComposer,
      $$SavedServersTableAnnotationComposer,
      $$SavedServersTableCreateCompanionBuilder,
      $$SavedServersTableUpdateCompanionBuilder,
      (
        SavedServerRow,
        BaseReferences<_$AppDatabase, $SavedServersTable, SavedServerRow>,
      ),
      SavedServerRow,
      PrefetchHooks Function()
    >;
typedef $$SavedAccountsTableCreateCompanionBuilder =
    SavedAccountsCompanion Function({
      required String id,
      required String serverId,
      required String userId,
      required String username,
      required int addedAt,
      Value<int> rowid,
    });
typedef $$SavedAccountsTableUpdateCompanionBuilder =
    SavedAccountsCompanion Function({
      Value<String> id,
      Value<String> serverId,
      Value<String> userId,
      Value<String> username,
      Value<int> addedAt,
      Value<int> rowid,
    });

class $$SavedAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $SavedAccountsTable> {
  $$SavedAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $SavedAccountsTable> {
  $$SavedAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SavedAccountsTable> {
  $$SavedAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$SavedAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SavedAccountsTable,
          SavedAccountRow,
          $$SavedAccountsTableFilterComposer,
          $$SavedAccountsTableOrderingComposer,
          $$SavedAccountsTableAnnotationComposer,
          $$SavedAccountsTableCreateCompanionBuilder,
          $$SavedAccountsTableUpdateCompanionBuilder,
          (
            SavedAccountRow,
            BaseReferences<_$AppDatabase, $SavedAccountsTable, SavedAccountRow>,
          ),
          SavedAccountRow,
          PrefetchHooks Function()
        > {
  $$SavedAccountsTableTableManager(_$AppDatabase db, $SavedAccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedAccountsCompanion(
                id: id,
                serverId: serverId,
                userId: userId,
                username: username,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String serverId,
                required String userId,
                required String username,
                required int addedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedAccountsCompanion.insert(
                id: id,
                serverId: serverId,
                userId: userId,
                username: username,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SavedAccountsTable,
      SavedAccountRow,
      $$SavedAccountsTableFilterComposer,
      $$SavedAccountsTableOrderingComposer,
      $$SavedAccountsTableAnnotationComposer,
      $$SavedAccountsTableCreateCompanionBuilder,
      $$SavedAccountsTableUpdateCompanionBuilder,
      (
        SavedAccountRow,
        BaseReferences<_$AppDatabase, $SavedAccountsTable, SavedAccountRow>,
      ),
      SavedAccountRow,
      PrefetchHooks Function()
    >;
typedef $$KeyValueEntriesTableCreateCompanionBuilder =
    KeyValueEntriesCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$KeyValueEntriesTableUpdateCompanionBuilder =
    KeyValueEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$KeyValueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValueEntriesTable> {
  $$KeyValueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValueEntriesTable> {
  $$KeyValueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValueEntriesTable> {
  $$KeyValueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$KeyValueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValueEntriesTable,
          KeyValueRow,
          $$KeyValueEntriesTableFilterComposer,
          $$KeyValueEntriesTableOrderingComposer,
          $$KeyValueEntriesTableAnnotationComposer,
          $$KeyValueEntriesTableCreateCompanionBuilder,
          $$KeyValueEntriesTableUpdateCompanionBuilder,
          (
            KeyValueRow,
            BaseReferences<_$AppDatabase, $KeyValueEntriesTable, KeyValueRow>,
          ),
          KeyValueRow,
          PrefetchHooks Function()
        > {
  $$KeyValueEntriesTableTableManager(
    _$AppDatabase db,
    $KeyValueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValueEntriesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => KeyValueEntriesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValueEntriesTable,
      KeyValueRow,
      $$KeyValueEntriesTableFilterComposer,
      $$KeyValueEntriesTableOrderingComposer,
      $$KeyValueEntriesTableAnnotationComposer,
      $$KeyValueEntriesTableCreateCompanionBuilder,
      $$KeyValueEntriesTableUpdateCompanionBuilder,
      (
        KeyValueRow,
        BaseReferences<_$AppDatabase, $KeyValueEntriesTable, KeyValueRow>,
      ),
      KeyValueRow,
      PrefetchHooks Function()
    >;
typedef $$CachedMediaItemsTableCreateCompanionBuilder =
    CachedMediaItemsCompanion Function({
      required String serverId,
      required String itemId,
      required String kind,
      required String name,
      required String availability,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      Value<String?> artistsJson,
      Value<String?> albumItemId,
      Value<String?> albumName,
      Value<int?> trackNumber,
      Value<int?> discNumber,
      Value<int?> durationMicros,
      Value<int?> productionYear,
      Value<int?> childCount,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CachedMediaItemsTableUpdateCompanionBuilder =
    CachedMediaItemsCompanion Function({
      Value<String> serverId,
      Value<String> itemId,
      Value<String> kind,
      Value<String> name,
      Value<String> availability,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      Value<String?> artistsJson,
      Value<String?> albumItemId,
      Value<String?> albumName,
      Value<int?> trackNumber,
      Value<int?> discNumber,
      Value<int?> durationMicros,
      Value<int?> productionYear,
      Value<int?> childCount,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CachedMediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedMediaItemsTable> {
  $$CachedMediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistsJson => $composableBuilder(
    column: $table.artistsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumItemId => $composableBuilder(
    column: $table.albumItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productionYear => $composableBuilder(
    column: $table.productionYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get childCount => $composableBuilder(
    column: $table.childCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedMediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedMediaItemsTable> {
  $$CachedMediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistsJson => $composableBuilder(
    column: $table.artistsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumItemId => $composableBuilder(
    column: $table.albumItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productionYear => $composableBuilder(
    column: $table.productionYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get childCount => $composableBuilder(
    column: $table.childCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedMediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedMediaItemsTable> {
  $$CachedMediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageKind =>
      $composableBuilder(column: $table.imageKind, builder: (column) => column);

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artistsJson => $composableBuilder(
    column: $table.artistsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumItemId => $composableBuilder(
    column: $table.albumItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get productionYear => $composableBuilder(
    column: $table.productionYear,
    builder: (column) => column,
  );

  GeneratedColumn<int> get childCount => $composableBuilder(
    column: $table.childCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedMediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedMediaItemsTable,
          CachedMediaItemRow,
          $$CachedMediaItemsTableFilterComposer,
          $$CachedMediaItemsTableOrderingComposer,
          $$CachedMediaItemsTableAnnotationComposer,
          $$CachedMediaItemsTableCreateCompanionBuilder,
          $$CachedMediaItemsTableUpdateCompanionBuilder,
          (
            CachedMediaItemRow,
            BaseReferences<
              _$AppDatabase,
              $CachedMediaItemsTable,
              CachedMediaItemRow
            >,
          ),
          CachedMediaItemRow,
          PrefetchHooks Function()
        > {
  $$CachedMediaItemsTableTableManager(
    _$AppDatabase db,
    $CachedMediaItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedMediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedMediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedMediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<String?> artistsJson = const Value.absent(),
                Value<String?> albumItemId = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> durationMicros = const Value.absent(),
                Value<int?> productionYear = const Value.absent(),
                Value<int?> childCount = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedMediaItemsCompanion(
                serverId: serverId,
                itemId: itemId,
                kind: kind,
                name: name,
                availability: availability,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                artistsJson: artistsJson,
                albumItemId: albumItemId,
                albumName: albumName,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMicros: durationMicros,
                productionYear: productionYear,
                childCount: childCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String itemId,
                required String kind,
                required String name,
                required String availability,
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<String?> artistsJson = const Value.absent(),
                Value<String?> albumItemId = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> durationMicros = const Value.absent(),
                Value<int?> productionYear = const Value.absent(),
                Value<int?> childCount = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedMediaItemsCompanion.insert(
                serverId: serverId,
                itemId: itemId,
                kind: kind,
                name: name,
                availability: availability,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                artistsJson: artistsJson,
                albumItemId: albumItemId,
                albumName: albumName,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMicros: durationMicros,
                productionYear: productionYear,
                childCount: childCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedMediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedMediaItemsTable,
      CachedMediaItemRow,
      $$CachedMediaItemsTableFilterComposer,
      $$CachedMediaItemsTableOrderingComposer,
      $$CachedMediaItemsTableAnnotationComposer,
      $$CachedMediaItemsTableCreateCompanionBuilder,
      $$CachedMediaItemsTableUpdateCompanionBuilder,
      (
        CachedMediaItemRow,
        BaseReferences<
          _$AppDatabase,
          $CachedMediaItemsTable,
          CachedMediaItemRow
        >,
      ),
      CachedMediaItemRow,
      PrefetchHooks Function()
    >;
typedef $$CachedCollectionsTableCreateCompanionBuilder =
    CachedCollectionsCompanion Function({
      required String serverId,
      required String collectionKey,
      required int totalCount,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CachedCollectionsTableUpdateCompanionBuilder =
    CachedCollectionsCompanion Function({
      Value<String> serverId,
      Value<String> collectionKey,
      Value<int> totalCount,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CachedCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCollectionsTable> {
  $$CachedCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCollectionsTable> {
  $$CachedCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCollectionsTable> {
  $$CachedCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCount => $composableBuilder(
    column: $table.totalCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCollectionsTable,
          CachedCollectionRow,
          $$CachedCollectionsTableFilterComposer,
          $$CachedCollectionsTableOrderingComposer,
          $$CachedCollectionsTableAnnotationComposer,
          $$CachedCollectionsTableCreateCompanionBuilder,
          $$CachedCollectionsTableUpdateCompanionBuilder,
          (
            CachedCollectionRow,
            BaseReferences<
              _$AppDatabase,
              $CachedCollectionsTable,
              CachedCollectionRow
            >,
          ),
          CachedCollectionRow,
          PrefetchHooks Function()
        > {
  $$CachedCollectionsTableTableManager(
    _$AppDatabase db,
    $CachedCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCollectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> collectionKey = const Value.absent(),
                Value<int> totalCount = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCollectionsCompanion(
                serverId: serverId,
                collectionKey: collectionKey,
                totalCount: totalCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String collectionKey,
                required int totalCount,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedCollectionsCompanion.insert(
                serverId: serverId,
                collectionKey: collectionKey,
                totalCount: totalCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCollectionsTable,
      CachedCollectionRow,
      $$CachedCollectionsTableFilterComposer,
      $$CachedCollectionsTableOrderingComposer,
      $$CachedCollectionsTableAnnotationComposer,
      $$CachedCollectionsTableCreateCompanionBuilder,
      $$CachedCollectionsTableUpdateCompanionBuilder,
      (
        CachedCollectionRow,
        BaseReferences<
          _$AppDatabase,
          $CachedCollectionsTable,
          CachedCollectionRow
        >,
      ),
      CachedCollectionRow,
      PrefetchHooks Function()
    >;
typedef $$CachedCollectionEntriesTableCreateCompanionBuilder =
    CachedCollectionEntriesCompanion Function({
      required String serverId,
      required String collectionKey,
      required int position,
      required String itemId,
      Value<String?> unavailableReason,
      Value<int> rowid,
    });
typedef $$CachedCollectionEntriesTableUpdateCompanionBuilder =
    CachedCollectionEntriesCompanion Function({
      Value<String> serverId,
      Value<String> collectionKey,
      Value<int> position,
      Value<String> itemId,
      Value<String?> unavailableReason,
      Value<int> rowid,
    });

class $$CachedCollectionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedCollectionEntriesTable> {
  $$CachedCollectionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unavailableReason => $composableBuilder(
    column: $table.unavailableReason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCollectionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedCollectionEntriesTable> {
  $$CachedCollectionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unavailableReason => $composableBuilder(
    column: $table.unavailableReason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCollectionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedCollectionEntriesTable> {
  $$CachedCollectionEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get collectionKey => $composableBuilder(
    column: $table.collectionKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get unavailableReason => $composableBuilder(
    column: $table.unavailableReason,
    builder: (column) => column,
  );
}

class $$CachedCollectionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedCollectionEntriesTable,
          CachedCollectionEntryRow,
          $$CachedCollectionEntriesTableFilterComposer,
          $$CachedCollectionEntriesTableOrderingComposer,
          $$CachedCollectionEntriesTableAnnotationComposer,
          $$CachedCollectionEntriesTableCreateCompanionBuilder,
          $$CachedCollectionEntriesTableUpdateCompanionBuilder,
          (
            CachedCollectionEntryRow,
            BaseReferences<
              _$AppDatabase,
              $CachedCollectionEntriesTable,
              CachedCollectionEntryRow
            >,
          ),
          CachedCollectionEntryRow,
          PrefetchHooks Function()
        > {
  $$CachedCollectionEntriesTableTableManager(
    _$AppDatabase db,
    $CachedCollectionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCollectionEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CachedCollectionEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CachedCollectionEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> collectionKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> unavailableReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCollectionEntriesCompanion(
                serverId: serverId,
                collectionKey: collectionKey,
                position: position,
                itemId: itemId,
                unavailableReason: unavailableReason,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String collectionKey,
                required int position,
                required String itemId,
                Value<String?> unavailableReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCollectionEntriesCompanion.insert(
                serverId: serverId,
                collectionKey: collectionKey,
                position: position,
                itemId: itemId,
                unavailableReason: unavailableReason,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCollectionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedCollectionEntriesTable,
      CachedCollectionEntryRow,
      $$CachedCollectionEntriesTableFilterComposer,
      $$CachedCollectionEntriesTableOrderingComposer,
      $$CachedCollectionEntriesTableAnnotationComposer,
      $$CachedCollectionEntriesTableCreateCompanionBuilder,
      $$CachedCollectionEntriesTableUpdateCompanionBuilder,
      (
        CachedCollectionEntryRow,
        BaseReferences<
          _$AppDatabase,
          $CachedCollectionEntriesTable,
          CachedCollectionEntryRow
        >,
      ),
      CachedCollectionEntryRow,
      PrefetchHooks Function()
    >;
typedef $$QueueEntriesTableCreateCompanionBuilder =
    QueueEntriesCompanion Function({
      Value<int> position,
      required String serverId,
      required String itemId,
      required String title,
      Value<String?> artist,
      Value<String?> albumName,
      Value<int?> durationMicros,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      Value<String> availability,
    });
typedef $$QueueEntriesTableUpdateCompanionBuilder =
    QueueEntriesCompanion Function({
      Value<int> position,
      Value<String> serverId,
      Value<String> itemId,
      Value<String> title,
      Value<String?> artist,
      Value<String?> albumName,
      Value<int?> durationMicros,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      Value<String> availability,
    });

class $$QueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueueEntriesTable> {
  $$QueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageKind =>
      $composableBuilder(column: $table.imageKind, builder: (column) => column);

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );
}

class $$QueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueueEntriesTable,
          QueueEntryRow,
          $$QueueEntriesTableFilterComposer,
          $$QueueEntriesTableOrderingComposer,
          $$QueueEntriesTableAnnotationComposer,
          $$QueueEntriesTableCreateCompanionBuilder,
          $$QueueEntriesTableUpdateCompanionBuilder,
          (
            QueueEntryRow,
            BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntryRow>,
          ),
          QueueEntryRow,
          PrefetchHooks Function()
        > {
  $$QueueEntriesTableTableManager(_$AppDatabase db, $QueueEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<int?> durationMicros = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<String> availability = const Value.absent(),
              }) => QueueEntriesCompanion(
                position: position,
                serverId: serverId,
                itemId: itemId,
                title: title,
                artist: artist,
                albumName: albumName,
                durationMicros: durationMicros,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                availability: availability,
              ),
          createCompanionCallback:
              ({
                Value<int> position = const Value.absent(),
                required String serverId,
                required String itemId,
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<int?> durationMicros = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<String> availability = const Value.absent(),
              }) => QueueEntriesCompanion.insert(
                position: position,
                serverId: serverId,
                itemId: itemId,
                title: title,
                artist: artist,
                albumName: albumName,
                durationMicros: durationMicros,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                availability: availability,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueueEntriesTable,
      QueueEntryRow,
      $$QueueEntriesTableFilterComposer,
      $$QueueEntriesTableOrderingComposer,
      $$QueueEntriesTableAnnotationComposer,
      $$QueueEntriesTableCreateCompanionBuilder,
      $$QueueEntriesTableUpdateCompanionBuilder,
      (
        QueueEntryRow,
        BaseReferences<_$AppDatabase, $QueueEntriesTable, QueueEntryRow>,
      ),
      QueueEntryRow,
      PrefetchHooks Function()
    >;
typedef $$TrackDownloadsTableCreateCompanionBuilder =
    TrackDownloadsCompanion Function({
      Value<String> accountKey,
      required String serverId,
      required String itemId,
      required String state,
      Value<bool> serverGone,
      Value<String?> failureReason,
      Value<int> receivedBytes,
      Value<int?> totalBytes,
      required String title,
      Value<String?> artistsJson,
      Value<String?> albumItemId,
      Value<String?> albumName,
      Value<int?> trackNumber,
      Value<int?> discNumber,
      Value<int?> durationMicros,
      Value<double?> normalizationGain,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      required int requestedAt,
      Value<int> rowid,
    });
typedef $$TrackDownloadsTableUpdateCompanionBuilder =
    TrackDownloadsCompanion Function({
      Value<String> accountKey,
      Value<String> serverId,
      Value<String> itemId,
      Value<String> state,
      Value<bool> serverGone,
      Value<String?> failureReason,
      Value<int> receivedBytes,
      Value<int?> totalBytes,
      Value<String> title,
      Value<String?> artistsJson,
      Value<String?> albumItemId,
      Value<String?> albumName,
      Value<int?> trackNumber,
      Value<int?> discNumber,
      Value<int?> durationMicros,
      Value<double?> normalizationGain,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      Value<int> requestedAt,
      Value<int> rowid,
    });

class $$TrackDownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackDownloadsTable> {
  $$TrackDownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get serverGone => $composableBuilder(
    column: $table.serverGone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artistsJson => $composableBuilder(
    column: $table.artistsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumItemId => $composableBuilder(
    column: $table.albumItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get normalizationGain => $composableBuilder(
    column: $table.normalizationGain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackDownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackDownloadsTable> {
  $$TrackDownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get serverGone => $composableBuilder(
    column: $table.serverGone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artistsJson => $composableBuilder(
    column: $table.artistsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumItemId => $composableBuilder(
    column: $table.albumItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumName => $composableBuilder(
    column: $table.albumName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get normalizationGain => $composableBuilder(
    column: $table.normalizationGain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackDownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackDownloadsTable> {
  $$TrackDownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<bool> get serverGone => $composableBuilder(
    column: $table.serverGone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureReason => $composableBuilder(
    column: $table.failureReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedBytes => $composableBuilder(
    column: $table.receivedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artistsJson => $composableBuilder(
    column: $table.artistsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumItemId => $composableBuilder(
    column: $table.albumItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get albumName =>
      $composableBuilder(column: $table.albumName, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMicros => $composableBuilder(
    column: $table.durationMicros,
    builder: (column) => column,
  );

  GeneratedColumn<double> get normalizationGain => $composableBuilder(
    column: $table.normalizationGain,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageKind =>
      $composableBuilder(column: $table.imageKind, builder: (column) => column);

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => column,
  );
}

class $$TrackDownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackDownloadsTable,
          TrackDownloadRow,
          $$TrackDownloadsTableFilterComposer,
          $$TrackDownloadsTableOrderingComposer,
          $$TrackDownloadsTableAnnotationComposer,
          $$TrackDownloadsTableCreateCompanionBuilder,
          $$TrackDownloadsTableUpdateCompanionBuilder,
          (
            TrackDownloadRow,
            BaseReferences<
              _$AppDatabase,
              $TrackDownloadsTable,
              TrackDownloadRow
            >,
          ),
          TrackDownloadRow,
          PrefetchHooks Function()
        > {
  $$TrackDownloadsTableTableManager(
    _$AppDatabase db,
    $TrackDownloadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackDownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackDownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackDownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<bool> serverGone = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artistsJson = const Value.absent(),
                Value<String?> albumItemId = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> durationMicros = const Value.absent(),
                Value<double?> normalizationGain = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<int> requestedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackDownloadsCompanion(
                accountKey: accountKey,
                serverId: serverId,
                itemId: itemId,
                state: state,
                serverGone: serverGone,
                failureReason: failureReason,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                title: title,
                artistsJson: artistsJson,
                albumItemId: albumItemId,
                albumName: albumName,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMicros: durationMicros,
                normalizationGain: normalizationGain,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                requestedAt: requestedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                required String serverId,
                required String itemId,
                required String state,
                Value<bool> serverGone = const Value.absent(),
                Value<String?> failureReason = const Value.absent(),
                Value<int> receivedBytes = const Value.absent(),
                Value<int?> totalBytes = const Value.absent(),
                required String title,
                Value<String?> artistsJson = const Value.absent(),
                Value<String?> albumItemId = const Value.absent(),
                Value<String?> albumName = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> durationMicros = const Value.absent(),
                Value<double?> normalizationGain = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                required int requestedAt,
                Value<int> rowid = const Value.absent(),
              }) => TrackDownloadsCompanion.insert(
                accountKey: accountKey,
                serverId: serverId,
                itemId: itemId,
                state: state,
                serverGone: serverGone,
                failureReason: failureReason,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
                title: title,
                artistsJson: artistsJson,
                albumItemId: albumItemId,
                albumName: albumName,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMicros: durationMicros,
                normalizationGain: normalizationGain,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                requestedAt: requestedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackDownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackDownloadsTable,
      TrackDownloadRow,
      $$TrackDownloadsTableFilterComposer,
      $$TrackDownloadsTableOrderingComposer,
      $$TrackDownloadsTableAnnotationComposer,
      $$TrackDownloadsTableCreateCompanionBuilder,
      $$TrackDownloadsTableUpdateCompanionBuilder,
      (
        TrackDownloadRow,
        BaseReferences<_$AppDatabase, $TrackDownloadsTable, TrackDownloadRow>,
      ),
      TrackDownloadRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadOwnersTableCreateCompanionBuilder =
    DownloadOwnersCompanion Function({
      Value<String> accountKey,
      required String serverId,
      required String itemId,
      required String ownerKind,
      required String ownerItemId,
      Value<int> rowid,
    });
typedef $$DownloadOwnersTableUpdateCompanionBuilder =
    DownloadOwnersCompanion Function({
      Value<String> accountKey,
      Value<String> serverId,
      Value<String> itemId,
      Value<String> ownerKind,
      Value<String> ownerItemId,
      Value<int> rowid,
    });

class $$DownloadOwnersTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadOwnersTable> {
  $$DownloadOwnersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerKind => $composableBuilder(
    column: $table.ownerKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerItemId => $composableBuilder(
    column: $table.ownerItemId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadOwnersTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadOwnersTable> {
  $$DownloadOwnersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerKind => $composableBuilder(
    column: $table.ownerKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerItemId => $composableBuilder(
    column: $table.ownerItemId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadOwnersTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadOwnersTable> {
  $$DownloadOwnersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get ownerKind =>
      $composableBuilder(column: $table.ownerKind, builder: (column) => column);

  GeneratedColumn<String> get ownerItemId => $composableBuilder(
    column: $table.ownerItemId,
    builder: (column) => column,
  );
}

class $$DownloadOwnersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadOwnersTable,
          DownloadOwnerRow,
          $$DownloadOwnersTableFilterComposer,
          $$DownloadOwnersTableOrderingComposer,
          $$DownloadOwnersTableAnnotationComposer,
          $$DownloadOwnersTableCreateCompanionBuilder,
          $$DownloadOwnersTableUpdateCompanionBuilder,
          (
            DownloadOwnerRow,
            BaseReferences<
              _$AppDatabase,
              $DownloadOwnersTable,
              DownloadOwnerRow
            >,
          ),
          DownloadOwnerRow,
          PrefetchHooks Function()
        > {
  $$DownloadOwnersTableTableManager(
    _$AppDatabase db,
    $DownloadOwnersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadOwnersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadOwnersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadOwnersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> ownerKind = const Value.absent(),
                Value<String> ownerItemId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadOwnersCompanion(
                accountKey: accountKey,
                serverId: serverId,
                itemId: itemId,
                ownerKind: ownerKind,
                ownerItemId: ownerItemId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                required String serverId,
                required String itemId,
                required String ownerKind,
                required String ownerItemId,
                Value<int> rowid = const Value.absent(),
              }) => DownloadOwnersCompanion.insert(
                accountKey: accountKey,
                serverId: serverId,
                itemId: itemId,
                ownerKind: ownerKind,
                ownerItemId: ownerItemId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadOwnersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadOwnersTable,
      DownloadOwnerRow,
      $$DownloadOwnersTableFilterComposer,
      $$DownloadOwnersTableOrderingComposer,
      $$DownloadOwnersTableAnnotationComposer,
      $$DownloadOwnersTableCreateCompanionBuilder,
      $$DownloadOwnersTableUpdateCompanionBuilder,
      (
        DownloadOwnerRow,
        BaseReferences<_$AppDatabase, $DownloadOwnersTable, DownloadOwnerRow>,
      ),
      DownloadOwnerRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistDownloadMembersTableCreateCompanionBuilder =
    PlaylistDownloadMembersCompanion Function({
      Value<String> accountKey,
      required String serverId,
      required String playlistItemId,
      required int position,
      required String trackItemId,
      Value<int> rowid,
    });
typedef $$PlaylistDownloadMembersTableUpdateCompanionBuilder =
    PlaylistDownloadMembersCompanion Function({
      Value<String> accountKey,
      Value<String> serverId,
      Value<String> playlistItemId,
      Value<int> position,
      Value<String> trackItemId,
      Value<int> rowid,
    });

class $$PlaylistDownloadMembersTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistDownloadMembersTable> {
  $$PlaylistDownloadMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playlistItemId => $composableBuilder(
    column: $table.playlistItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackItemId => $composableBuilder(
    column: $table.trackItemId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistDownloadMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistDownloadMembersTable> {
  $$PlaylistDownloadMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playlistItemId => $composableBuilder(
    column: $table.playlistItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackItemId => $composableBuilder(
    column: $table.trackItemId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistDownloadMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistDownloadMembersTable> {
  $$PlaylistDownloadMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get playlistItemId => $composableBuilder(
    column: $table.playlistItemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get trackItemId => $composableBuilder(
    column: $table.trackItemId,
    builder: (column) => column,
  );
}

class $$PlaylistDownloadMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistDownloadMembersTable,
          PlaylistDownloadMemberRow,
          $$PlaylistDownloadMembersTableFilterComposer,
          $$PlaylistDownloadMembersTableOrderingComposer,
          $$PlaylistDownloadMembersTableAnnotationComposer,
          $$PlaylistDownloadMembersTableCreateCompanionBuilder,
          $$PlaylistDownloadMembersTableUpdateCompanionBuilder,
          (
            PlaylistDownloadMemberRow,
            BaseReferences<
              _$AppDatabase,
              $PlaylistDownloadMembersTable,
              PlaylistDownloadMemberRow
            >,
          ),
          PlaylistDownloadMemberRow,
          PrefetchHooks Function()
        > {
  $$PlaylistDownloadMembersTableTableManager(
    _$AppDatabase db,
    $PlaylistDownloadMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistDownloadMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PlaylistDownloadMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaylistDownloadMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> playlistItemId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> trackItemId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistDownloadMembersCompanion(
                accountKey: accountKey,
                serverId: serverId,
                playlistItemId: playlistItemId,
                position: position,
                trackItemId: trackItemId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                required String serverId,
                required String playlistItemId,
                required int position,
                required String trackItemId,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistDownloadMembersCompanion.insert(
                accountKey: accountKey,
                serverId: serverId,
                playlistItemId: playlistItemId,
                position: position,
                trackItemId: trackItemId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistDownloadMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistDownloadMembersTable,
      PlaylistDownloadMemberRow,
      $$PlaylistDownloadMembersTableFilterComposer,
      $$PlaylistDownloadMembersTableOrderingComposer,
      $$PlaylistDownloadMembersTableAnnotationComposer,
      $$PlaylistDownloadMembersTableCreateCompanionBuilder,
      $$PlaylistDownloadMembersTableUpdateCompanionBuilder,
      (
        PlaylistDownloadMemberRow,
        BaseReferences<
          _$AppDatabase,
          $PlaylistDownloadMembersTable,
          PlaylistDownloadMemberRow
        >,
      ),
      PlaylistDownloadMemberRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadedCollectionsTableCreateCompanionBuilder =
    DownloadedCollectionsCompanion Function({
      Value<String> accountKey,
      required String serverId,
      required String ownerKind,
      required String ownerItemId,
      required String name,
      Value<String> sortName,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$DownloadedCollectionsTableUpdateCompanionBuilder =
    DownloadedCollectionsCompanion Function({
      Value<String> accountKey,
      Value<String> serverId,
      Value<String> ownerKind,
      Value<String> ownerItemId,
      Value<String> name,
      Value<String> sortName,
      Value<String?> imageItemId,
      Value<String?> imageKind,
      Value<String?> imageTag,
      Value<double?> imageAspectRatio,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$DownloadedCollectionsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedCollectionsTable> {
  $$DownloadedCollectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerKind => $composableBuilder(
    column: $table.ownerKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerItemId => $composableBuilder(
    column: $table.ownerItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sortName => $composableBuilder(
    column: $table.sortName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadedCollectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedCollectionsTable> {
  $$DownloadedCollectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerKind => $composableBuilder(
    column: $table.ownerKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerItemId => $composableBuilder(
    column: $table.ownerItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sortName => $composableBuilder(
    column: $table.sortName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageKind => $composableBuilder(
    column: $table.imageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadedCollectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedCollectionsTable> {
  $$DownloadedCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get ownerKind =>
      $composableBuilder(column: $table.ownerKind, builder: (column) => column);

  GeneratedColumn<String> get ownerItemId => $composableBuilder(
    column: $table.ownerItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sortName =>
      $composableBuilder(column: $table.sortName, builder: (column) => column);

  GeneratedColumn<String> get imageItemId => $composableBuilder(
    column: $table.imageItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageKind =>
      $composableBuilder(column: $table.imageKind, builder: (column) => column);

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<double> get imageAspectRatio => $composableBuilder(
    column: $table.imageAspectRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DownloadedCollectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadedCollectionsTable,
          DownloadedCollectionRow,
          $$DownloadedCollectionsTableFilterComposer,
          $$DownloadedCollectionsTableOrderingComposer,
          $$DownloadedCollectionsTableAnnotationComposer,
          $$DownloadedCollectionsTableCreateCompanionBuilder,
          $$DownloadedCollectionsTableUpdateCompanionBuilder,
          (
            DownloadedCollectionRow,
            BaseReferences<
              _$AppDatabase,
              $DownloadedCollectionsTable,
              DownloadedCollectionRow
            >,
          ),
          DownloadedCollectionRow,
          PrefetchHooks Function()
        > {
  $$DownloadedCollectionsTableTableManager(
    _$AppDatabase db,
    $DownloadedCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedCollectionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DownloadedCollectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DownloadedCollectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> ownerKind = const Value.absent(),
                Value<String> ownerItemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sortName = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadedCollectionsCompanion(
                accountKey: accountKey,
                serverId: serverId,
                ownerKind: ownerKind,
                ownerItemId: ownerItemId,
                name: name,
                sortName: sortName,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                required String serverId,
                required String ownerKind,
                required String ownerItemId,
                required String name,
                Value<String> sortName = const Value.absent(),
                Value<String?> imageItemId = const Value.absent(),
                Value<String?> imageKind = const Value.absent(),
                Value<String?> imageTag = const Value.absent(),
                Value<double?> imageAspectRatio = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DownloadedCollectionsCompanion.insert(
                accountKey: accountKey,
                serverId: serverId,
                ownerKind: ownerKind,
                ownerItemId: ownerItemId,
                name: name,
                sortName: sortName,
                imageItemId: imageItemId,
                imageKind: imageKind,
                imageTag: imageTag,
                imageAspectRatio: imageAspectRatio,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadedCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadedCollectionsTable,
      DownloadedCollectionRow,
      $$DownloadedCollectionsTableFilterComposer,
      $$DownloadedCollectionsTableOrderingComposer,
      $$DownloadedCollectionsTableAnnotationComposer,
      $$DownloadedCollectionsTableCreateCompanionBuilder,
      $$DownloadedCollectionsTableUpdateCompanionBuilder,
      (
        DownloadedCollectionRow,
        BaseReferences<
          _$AppDatabase,
          $DownloadedCollectionsTable,
          DownloadedCollectionRow
        >,
      ),
      DownloadedCollectionRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SavedServersTableTableManager get savedServers =>
      $$SavedServersTableTableManager(_db, _db.savedServers);
  $$SavedAccountsTableTableManager get savedAccounts =>
      $$SavedAccountsTableTableManager(_db, _db.savedAccounts);
  $$KeyValueEntriesTableTableManager get keyValueEntries =>
      $$KeyValueEntriesTableTableManager(_db, _db.keyValueEntries);
  $$CachedMediaItemsTableTableManager get cachedMediaItems =>
      $$CachedMediaItemsTableTableManager(_db, _db.cachedMediaItems);
  $$CachedCollectionsTableTableManager get cachedCollections =>
      $$CachedCollectionsTableTableManager(_db, _db.cachedCollections);
  $$CachedCollectionEntriesTableTableManager get cachedCollectionEntries =>
      $$CachedCollectionEntriesTableTableManager(
        _db,
        _db.cachedCollectionEntries,
      );
  $$QueueEntriesTableTableManager get queueEntries =>
      $$QueueEntriesTableTableManager(_db, _db.queueEntries);
  $$TrackDownloadsTableTableManager get trackDownloads =>
      $$TrackDownloadsTableTableManager(_db, _db.trackDownloads);
  $$DownloadOwnersTableTableManager get downloadOwners =>
      $$DownloadOwnersTableTableManager(_db, _db.downloadOwners);
  $$PlaylistDownloadMembersTableTableManager get playlistDownloadMembers =>
      $$PlaylistDownloadMembersTableTableManager(
        _db,
        _db.playlistDownloadMembers,
      );
  $$DownloadedCollectionsTableTableManager get downloadedCollections =>
      $$DownloadedCollectionsTableTableManager(_db, _db.downloadedCollections);
}
