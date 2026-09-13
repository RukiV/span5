import 'package:flutter/material.dart';

Color jobStatusColor(String status) {
  switch (status) {
    case 'Besig':
      return Colors.blue;
    case 'Geskeduleer':
      return Colors.teal;
    case 'Voltooi':
      return Colors.green;
    case 'Oop':
      return Colors.orange;
    case 'Wag':
      return Colors.amber;
    case 'Gekanselleer':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
