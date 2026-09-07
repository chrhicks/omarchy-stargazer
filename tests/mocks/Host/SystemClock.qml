import QtQuick

QtObject {
  enum Precision {
    Minutes
  }

  property int precision
  property date date: new Date("2026-09-07T02:30:00Z")
}
