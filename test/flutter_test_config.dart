import 'package:flutter_test/flutter_test.dart';
import 'package:transworld_nexus/core/widgets/action_lock.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ActionLock.instance.unlock);
  await testMain();
}
