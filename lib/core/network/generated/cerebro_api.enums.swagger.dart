// coverage:ignore-file
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';
import 'package:collection/collection.dart';

enum CreateTodoBodyPriority {
  @JsonValue(null)
  swaggerGeneratedUnknown(null),

  @JsonValue('low')
  low('low'),
  @JsonValue('medium')
  medium('medium'),
  @JsonValue('high')
  high('high');

  final String? value;

  const CreateTodoBodyPriority(this.value);
}

enum UpdateTodoBodyPriority {
  @JsonValue(null)
  swaggerGeneratedUnknown(null),

  @JsonValue('low')
  low('low'),
  @JsonValue('medium')
  medium('medium'),
  @JsonValue('high')
  high('high');

  final String? value;

  const UpdateTodoBodyPriority(this.value);
}
