package nested;

class Dummy {
  public function new() {}
  static public var p(default, never) = new Private();
}

private class Private {
  public function new() {}
}