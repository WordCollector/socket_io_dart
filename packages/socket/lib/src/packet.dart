import 'dart:convert';
import 'dart:math';

import 'package:fpdart/fpdart.dart';

/// The revision of the Socket.IO protocol implemented.
const protocolRevision = 5;

/// A regular expression matching to a valid encoded packet.
final encodedPacketExpression = RegExp(
  '^([0-${max(0, PacketType.values.length - 1)}])(\\d)?([a-zA-Z/]+,)(\\d+)?([.*?]|{.*?})?\$',
);

/// The type of packet sent.
enum PacketType {
  /// The event used when:
  /// - The client requests access to a given namespace.
  /// - The server grants access to a given namespace.
  connect,

  /// The event used when:
  /// - The client disconnects from a given namespace.
  /// - The server disconnects a client from a given namespace.
  disconnect,

  /// The event used when one side wants to transmit data to the other.
  ///
  /// A packet with a `PacketType` of `PacketType.event` __cannot__ have a
  /// payload containing binary data. If you wish to transmit binary data, send
  /// a packet with a `PacketType` of `PacketType.binaryAck` instead.
  event,

  /// The event used to acknowledge a packet with a `PacketType` of
  /// `PacketType.event` or `PacketType.binaryEvent`.
  ack,

  /// The event used by the server to signal to the client that the request for
  /// access to a given namespace has been refused.
  connectError,

  /// The event used when one side wants to transmit data to the other.
  binaryEvent,

  /// The event used to acknowledge a packet with a `PacketType` of
  /// `PacketType.event` or `PacketType.binaryEvent`.
  binaryAck,
}

/// Represents a message passed between a server and a client.
abstract class Packet {
  /// The type of this packet.
  final PacketType type;

  /// The namespace this packet pertains to.
  final String namespace;

  /// Creates an instance of `Packet`.
  const Packet({
    required this.type,
    required this.namespace,
  });

  /// Indicates whether the packet accesses the main namespace or not.
  bool get _isMainNamespace => namespace == '/';

  /// Gets the head of the packet in its encoded format.
  String get _headEncoded =>
      '${type.index}${_isMainNamespace ? '' : namespace}';

  /// Gets the body of the packet in its encoded format.
  String get _bodyEncoded;

  /// Gets the packet in its encoded format.
  String get encoded => '$_headEncoded$_bodyEncoded';
}

/// Fields that are part of the payload, as defined in the socket.io protocol
/// specification.
class PayloadFields {
  /// The data content of the packet.
  static const data = 'data';

  /// The session identifier of the client the packet was sent from.
  static const sessionIdentifier = 'id';
}

/// Fields that can be a part of the data object sent with the payload, as
/// defined in the socket.io protocol specification.
class ConnectErrorDataFields {
  /// An error message describing the reason for the connection error.
  static const message = 'message';

  /// The data passed together with the connection error.
  static const data = 'data';
}

/// Fields that are not part of the socket.io protocol specification, but are
/// used internally by this package for the parsing of binary packets.
class BinaryPacketPayloadFields {
  /// The number of binary attachments sent with a binary packet.
  static const attachmentsCount = 'attachmentsCount';

  /// The binary content of a binary packet.
  static const binary = 'binary';
}

/// Represents a packet with additional binary data.
abstract class BinaryPacket extends Packet {
  /// The bytes sent with this packet.
  final List<int> buffer;

  /// Creates an instance of `BinaryPacket`.
  const BinaryPacket({
    required super.type,
    required super.namespace,
    required this.buffer,
  });
}

/// Represents a packet with the type `PacketType.connect`.
class ConnectPacket extends Packet {
  /// The data sent together with the packet.
  final Object? data;

  /// Creates an instance of `ConnectPacket`.
  const ConnectPacket({
    required super.namespace,
    this.data,
  }) : super(type: PacketType.connect);

  @override
  String get _bodyEncoded => data == null ? '' : json.encode(data);
}

/// Represents a packet with the type `PacketType.disconnect`.
class DisconnectPacket extends Packet {
  /// Creates an instance of `DisconnectPacket`.
  const DisconnectPacket({
    required super.namespace,
  }) : super(type: PacketType.disconnect);

  @override
  String get _bodyEncoded => ''; // DISCONNECT packets do not have bodies.
}

/// Represents a packet with the type `PacketType.event`.
class EventPacket extends Packet {
  /// The data sent with this packet.
  final Object data;

  /// (Optional) The ID to use to acknowledge this packet.
  final int? id;

  /// Creates an instance of `EventPacket`.
  const EventPacket({
    required super.namespace,
    required this.data,
    this.id,
  }) : super(type: PacketType.event);

  @override
  String get _bodyEncoded => '${id ?? ''}${json.encode(data)}';
}

/// Represents a packet with the type `PacketType.ack`.
class AckPacket extends Packet {
  /// The ID of the acknowledged packet.
  final int id;

  /// (Optional) The data sent with this packet.
  final Object? data;

  /// Creates an instance of `AckPacket`.
  const AckPacket({
    required super.namespace,
    required this.id,
    this.data,
  }) : super(type: PacketType.ack);

  @override
  String get _bodyEncoded => '$id${json.encode(data)}';
}

/// Represents a packet with the type `PacketType.connectError`.
class ConnectErrorPacket extends Packet {
  /// The reason for the error.
  final String message;

  /// (Optional) The data sent with this packet.
  final Object? data;

  /// Creates an instance of `ConnectErrorPacket`.
  const ConnectErrorPacket({
    required super.namespace,
    required this.message,
    this.data,
  }) : super(type: PacketType.connectError);

  @override
  String get _bodyEncoded {
    final data = <String, dynamic>{
      ConnectErrorDataFields.message: message,
      if (this.data != null) ConnectErrorDataFields.data: this.data,
    };

    return json.encode(data);
  }
}

/// Represents a packet with the type `PacketType.binaryEvent`.
class BinaryEventPacket extends BinaryPacket {
  /// The standard data sent with this packet.
  final Object data;

  /// (Optional) The ID to use to acknowledge this packet.
  final int? id;

  /// Creates an instance of `BinaryEventPacket`.
  const BinaryEventPacket({
    required super.namespace,
    required this.data,
    required super.buffer,
    this.id,
  }) : super(type: PacketType.binaryEvent);

  @override
  String get _bodyEncoded => json.encode(data);
}

/// Represents a packet with the type `PacketType.binaryAck`.
class BinaryAckPacket extends BinaryPacket {
  /// The data sent with this packet.
  final Object data;

  /// The ID of the acknowledged packet.
  final int id;

  /// Creates an instance of `BinaryAckPacket`.
  const BinaryAckPacket({
    required super.namespace,
    required this.data,
    required super.buffer,
    required this.id,
  }) : super(type: PacketType.binaryAck);

  @override
  String get _bodyEncoded => '$id${json.encode(data)}';
}

/// Defines a function that, taking a [namespace] and [data] associated with a
/// packet, constructs an instance of a given packet.
typedef PacketConstructor = Packet Function(
  String namespace,
  Map<String, dynamic> data,
);

/// Stores information about the [required] and [allowed] properties for a
/// given packet type.
class PacketPayloadRuleset {
  /// The properties required to be present in the payload.
  final List<String> required;

  /// The properties allowed, but not required to be present in the payload.
  final List<String> allowed;

  /// The properties required to be present in the data object of the payload.
  final List<String> requiredData;

  /// The properties allowed, but not required to be present in the data object
  /// of the payload.
  final List<String> allowedData;

  /// Indicates whether this ruleset allows any data to be passed.
  final bool allowsAnyData;

  /// Constructs an instance of `PacketPayloadRuleset`.
  const PacketPayloadRuleset({
    required this.required,
    required this.allowed,
    List<String>? requiredData,
    List<String>? allowedData,
  })  : allowsAnyData = requiredData == null && allowedData == null,
        requiredData = requiredData ?? const [],
        allowedData = allowedData ?? const [];

  /// Verifies whether this ruleset allows a given payload.
  bool verifyPayload(Map<String, dynamic> payload) {
    final presentKeys = payload.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key);

    return required.all(presentKeys.contains) &&
        !presentKeys.any((key) => !allowed.contains(key));
  }

  /// Verifies whether this ruleset allows a given data object.
  bool verifyData(Object? data) {
    if (allowsAnyData) {
      return true;
    }

    if (data == null) {
      if (required.isNotEmpty) {
        return false;
      }

      return true;
    }

    if (data is List) {
      return false;
    }

    data as Map<String, dynamic>;

    final presentKeys = data.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key);

    return requiredData.all(presentKeys.contains) &&
        !presentKeys.any((key) => !allowedData.contains(key));
  }
}

/// `PacketPayloadRuleset`s matched to `PacketType`s to verify that a packet's
/// payload is valid.
const Map<PacketType, PacketPayloadRuleset> packetPayloadRulesets = {
  PacketType.connect: PacketPayloadRuleset(
    required: [],
    allowed: [PayloadFields.data],
  ),
  PacketType.disconnect: PacketPayloadRuleset(
    required: [],
    allowed: [],
  ),
  PacketType.event: PacketPayloadRuleset(
    required: [PayloadFields.data],
    allowed: [PayloadFields.data, PayloadFields.sessionIdentifier],
  ),
  PacketType.ack: PacketPayloadRuleset(
    required: [PayloadFields.sessionIdentifier],
    allowed: [PayloadFields.data, PayloadFields.sessionIdentifier],
  ),
  PacketType.connectError: PacketPayloadRuleset(
    required: [PayloadFields.data],
    allowed: [PayloadFields.data],
    requiredData: [ConnectErrorDataFields.message],
    allowedData: [
      ConnectErrorDataFields.message,
      ConnectErrorDataFields.data,
    ],
  ),
  PacketType.binaryEvent: PacketPayloadRuleset(
    required: [
      BinaryPacketPayloadFields.attachmentsCount,
      BinaryPacketPayloadFields.binary,
      PayloadFields.data,
    ],
    allowed: [
      BinaryPacketPayloadFields.attachmentsCount,
      BinaryPacketPayloadFields.binary,
      PayloadFields.data,
      PayloadFields.sessionIdentifier,
    ],
  ),
  PacketType.binaryAck: PacketPayloadRuleset(
    required: [
      BinaryPacketPayloadFields.attachmentsCount,
      BinaryPacketPayloadFields.binary,
      PayloadFields.data,
      PayloadFields.sessionIdentifier,
    ],
    allowed: [
      BinaryPacketPayloadFields.attachmentsCount,
      BinaryPacketPayloadFields.binary,
      PayloadFields.data,
      PayloadFields.sessionIdentifier,
    ],
  ),
};

/// `PacketConstructor`s matched to `PacketType`s to create an instance of the
/// respective packet.
final Map<PacketType, PacketConstructor> packetConstructors = Map.unmodifiable(
  <PacketType, PacketConstructor>{
    PacketType.connect: (namespace, data) => ConnectPacket(
          namespace: namespace,
          data: data[PayloadFields.data] as Object?,
        ),
    PacketType.disconnect: (namespace, _) =>
        DisconnectPacket(namespace: namespace),
    PacketType.event: (namespace, data) => EventPacket(
          namespace: namespace,
          data: data[PayloadFields.data] as Object,
          id: data[PayloadFields.sessionIdentifier] as int?,
        ),
    PacketType.ack: (namespace, data) => AckPacket(
          namespace: namespace,
          data: data[PayloadFields.data] as Object?,
          id: data[PayloadFields.sessionIdentifier] as int,
        ),
    PacketType.connectError: (namespace, data) => ConnectErrorPacket(
          namespace: namespace,
          message: data[PayloadFields.data][ConnectErrorDataFields.message]
              as String,
          data: data[PayloadFields.data]?[ConnectErrorDataFields.message]
              as Object?,
        ),
    PacketType.binaryEvent: (namespace, data) => BinaryEventPacket(
          namespace: namespace,
          data: data[PayloadFields.data] as Object,
          buffer: data[BinaryPacketPayloadFields.binary] as List<int>,
          id: data[PayloadFields.sessionIdentifier] as int?,
        ),
    PacketType.binaryAck: (namespace, data) => BinaryAckPacket(
          namespace: namespace,
          data: data[PayloadFields.data] as Object,
          buffer: data[BinaryPacketPayloadFields.binary] as List<int>,
          id: data[PayloadFields.sessionIdentifier] as int,
        ),
  },
);

/// Attempts to decode a string into a `Packet`, returning a `Packet` if
/// succeeded, and an error message otherwise.
Future<Either<Packet, String>> decodePacket(
  String encodedPacket,
  Stream<List<int>> stream,
) async {
  final regexMatch = encodedPacketExpression.firstMatch(encodedPacket);
  if (regexMatch == null) {
    return const Right('The packet is invalid.');
  }

  final groups = regexMatch.groups([1, 2, 3, 4, 5]);

  final packetType = PacketType.values[int.parse(groups[0]!)];
  final namespace = groups[2]!;

  final dataString = groups[4];
  final Option<Either<Map<String, dynamic>, List<dynamic>>> dataOption;
  try {
    if (dataString == null) {
      dataOption = const None();
    } else {
      final decoded = json.decode(dataString) as Object;

      if (decoded is Map) {
        dataOption = Some(Either.left(Map<String, dynamic>.from(decoded)));
      } else {
        dataOption = Some(Either.right(List<dynamic>.from(decoded as List)));
      }
    }
  } on FormatException {
    return const Right('The packet data object is not valid JSON.');
  }

  final data = dataOption.match(
    (either) =>
        (either.isLeft() ? either.getLeft() : either.getRight()).toNullable()!,
    () => null,
  );

  final attachmentsCount = groups[1] == null ? null : int.parse(groups[1]!);

  final payload = <String, dynamic>{
    PayloadFields.sessionIdentifier:
        groups[3] == null ? null : int.parse(groups[3]!),
    PayloadFields.data: data,
    BinaryPacketPayloadFields.attachmentsCount: attachmentsCount,
    if (attachmentsCount != null) BinaryPacketPayloadFields.binary: <int>[],
  };

  final ruleset = packetPayloadRulesets[packetType]!;

  if (!ruleset.verifyPayload(payload)) {
    return const Right('The packet payload is invalid.');
  }

  if (!ruleset.verifyData(data)) {
    return const Right(
      'The data object in the packet payload contains invalid fields.',
    );
  }

  if (packetType == PacketType.binaryEvent ||
      packetType == PacketType.binaryAck) {
    if (attachmentsCount == 0) {
      return const Right(
        'A packet of type BINARY_EVENT or BINARY_ACK must feature binary data.'
        ' Instead, consider using an EVENT or ACK packet respectively.',
      );
    }

    final streamView = stream.take(attachmentsCount!);

    final buffer = <int>[];
    await for (final bytes in streamView) {
      buffer.addAll(bytes);
    }

    payload[BinaryPacketPayloadFields.binary] = buffer;
  }

  final packet = packetConstructors[packetType]!(namespace, payload);

  return Left(packet);
}
