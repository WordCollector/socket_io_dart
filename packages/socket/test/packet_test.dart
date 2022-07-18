import 'package:fpdart/fpdart.dart';
import 'package:socket_io_dart/src/packet.dart';
import 'package:test/test.dart';

class IsValidEncodedPacket extends Matcher {
  const IsValidEncodedPacket();

  bool _matches(Either<Packet, String> encodedPacket) => encodedPacket.isLeft();

  @override
  bool matches(dynamic encodedPacket, _) => _matches(
        encodedPacket as Either<Packet, String>,
      );

  @override
  Description describe(Description description) =>
      description.add('is a valid encoded packet.');

  @override
  Description describeMismatch(
    dynamic encodedPacket,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) =>
      mismatchDescription
          .add("'$encodedPacket' is not a valid encoded packet.");
}

class IsInvalidEncodedPacket extends Matcher {
  const IsInvalidEncodedPacket();

  bool _matches(Either<Packet, String> encodedPacket) =>
      encodedPacket.isRight();

  @override
  bool matches(dynamic encodedPacket, _) => _matches(
        encodedPacket as Either<Packet, String>,
      );

  @override
  Description describe(Description description) =>
      description.add('is not a valid encoded packet.');

  @override
  Description describeMismatch(
    dynamic encodedPacket,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) =>
      mismatchDescription.add("'$encodedPacket' is a valid encoded packet.");
}

const isValidPacket = IsValidEncodedPacket();
const isInvalidPacket = IsInvalidEncodedPacket();

Stream<List<int>> dummyStream() async* {
  while (true) {
    await Future<dynamic>.delayed(const Duration(seconds: 10));
    yield [];
  }
}

Future<void> expectDecodePacket(String encodedPacket, Matcher matcher) async {
  final emptyStream = Stream<List<int>>.fromIterable([]);

  final packet = await decodePacket(encodedPacket, emptyStream);

  expect(packet, matcher);
}

Future main() async {
  group('Decoding packets:', () {
    test(
      'With just the packet type.',
      () => expectDecodePacket('0', isInvalidPacket),
    );

    test(
      'With just the namespace.',
      () => expectDecodePacket('/,', isInvalidPacket),
    );

    test(
      'With an invalid packet type.',
      () => expectDecodePacket('9/,', isInvalidPacket),
    );

    group('CONNECT packet:', () {
      test('Without payload.', () => expectDecodePacket('0/,', isValidPacket));

      test('With payload.', () => expectDecodePacket('0/,{}', isValidPacket));

      test(
        'With attachments count.',
        () => expectDecodePacket('00/,', isInvalidPacket),
      );

      test(
        'With acknowledgement ID.',
        () => expectDecodePacket('0/,7031', isInvalidPacket),
      );

      test(
        'With attachments count + acknowledgement ID.',
        () => expectDecodePacket('00/,7031', isInvalidPacket),
      );

      test(
        'With attachments count + payload.',
        () => expectDecodePacket('00/,{}', isInvalidPacket),
      );
    });

    group('DISCONNECT packet:', () {
      test('Without payload.', () => expectDecodePacket('1/,', isValidPacket));

      test('With payload.', () => expectDecodePacket('1/,{}', isInvalidPacket));
    });

    group('EVENT packet:', () {
      test(
        'Without payload.',
        () => expectDecodePacket('2/,', isInvalidPacket),
      );

      test('With payload.', () => expectDecodePacket('2/,{}', isValidPacket));

      test(
        'With acknowledgement ID + payload.',
        () => expectDecodePacket('2/,7031{}', isValidPacket),
      );

      test(
        'With acknowledgement ID but no payload.',
        () => expectDecodePacket('2/,7031', isInvalidPacket),
      );
    });

    group('ACK packet:', () {
      test(
        'Without payload.',
        () => expectDecodePacket('3/,', isInvalidPacket),
      );

      test('With payload.', () => expectDecodePacket('3/,{}', isInvalidPacket));

      test(
        'With acknowledgement ID + payload.',
        () => expectDecodePacket('3/,7031{}', isValidPacket),
      );

      test(
        'With acknowledgement ID but no payload.',
        () => expectDecodePacket('3/,7031', isValidPacket),
      );
    });

    group('CONNECT_ERROR packet:', () {
      test(
        'Without payload.',
        () => expectDecodePacket('4/,', isInvalidPacket),
      );

      test(
        'With empty payload.',
        () => expectDecodePacket('4/,{}', isInvalidPacket),
      );

      test(
        "With payload with just a 'data' field.",
        () => expectDecodePacket('4/,{"data":{}}', isInvalidPacket),
      );

      test(
        "With payload with just a 'message' field.",
        () => expectDecodePacket(
          '4/,{"message":"Sample message."}',
          isValidPacket,
        ),
      );

      test(
        "With payload with both a 'message' and 'data' field.",
        () => expectDecodePacket(
          '4/,{"message":"Sample message.","data":{}}',
          isValidPacket,
        ),
      );

      test(
        '''With payload with both a 'message' and 'data' field and another, unknown field.''',
        () => expectDecodePacket(
          '4/,{"message":"Sample message.","data":{},"other": false}',
          isInvalidPacket,
        ),
      );
    });

    group('BINARY_EVENT packet:', () {
      test(
        'Without payload.',
        () => expectDecodePacket('5/,', isInvalidPacket),
      );

      test('With payload.', () => expectDecodePacket('5/,{}', isInvalidPacket));

      test(
        'With acknowledgement ID + payload.',
        () => expectDecodePacket('5/,{}', isInvalidPacket),
      );

      test(
        'With acknowledgement ID + payload.',
        () => expectDecodePacket('5/,7031{}', isInvalidPacket),
      );

      test(
        'With acknowledgement ID but no payload.',
        () => expectDecodePacket('5/,7031', isInvalidPacket),
      );

      test(
        'With attachment count but no payload.',
        () => expectDecodePacket('51/,', isInvalidPacket),
      );

      test(
        'With attachment count + payload.',
        () => expectDecodePacket('51/,{}', isValidPacket),
      );
    });

    group('BINARY_ACK packet:', () {
      test(
        'Without payload.',
        () => expectDecodePacket('6/,', isInvalidPacket),
      );

      test('With payload.', () => expectDecodePacket('6/,{}', isInvalidPacket));

      test(
        'With acknowledgement ID + payload.',
        () => expectDecodePacket('6/,7031{}', isInvalidPacket),
      );

      test(
        'With acknowledgement ID but no payload.',
        () => expectDecodePacket('6/,7031', isInvalidPacket),
      );

      test(
        'With attachment count + acknowledgement ID + payload.',
        () => expectDecodePacket('61/,7031{}', isValidPacket),
      );

      test(
        'With attachment count + acknowledgement ID but no payload.',
        () => expectDecodePacket('61/,7031', isInvalidPacket),
      );
    });
  });
}
