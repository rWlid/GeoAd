import 'dart:async';

class FakePollTimers {
  final List<FakeTimer> started = <FakeTimer>[];

  List<FakeTimer> get pending =>
      started.where((FakeTimer timer) => timer.isActive).toList();

  Timer call(Duration duration, void Function() onTick) {
    final FakeTimer timer = FakeTimer(duration, onTick);
    started.add(timer);
    return timer;
  }

  void fire() {
    final List<FakeTimer> timers = pending;
    if (timers.length != 1) {
      throw StateError('${timers.length} timers pending, expected 1');
    }
    timers.single.fire();
  }
}

class FakeTimer implements Timer {
  FakeTimer(this.duration, this._onTick);

  final Duration duration;
  final void Function() _onTick;
  bool _active = true;

  void fire() {
    _active = false;
    _onTick();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
