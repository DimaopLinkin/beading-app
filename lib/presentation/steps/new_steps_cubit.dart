import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:beading/domain/steps/use_cases/create_step_pattern.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum NewStepsProblem { createFailed, photosFailed }

class NewStepsState extends Equatable {
  const NewStepsState({this.templates = const <StepTemplate>[], this.busy = false, this.problem, this.createdId});

  final List<StepTemplate> templates;
  final bool busy;
  final NewStepsProblem? problem;

  /// Проект создан: экран закрывается с этим id.
  final String? createdId;

  NewStepsState copyWith({
    List<StepTemplate>? templates,
    bool? busy,
    NewStepsProblem? problem,
    bool clearProblem = false,
    String? createdId,
  }) => NewStepsState(
    templates: templates ?? this.templates,
    busy: busy ?? this.busy,
    problem: clearProblem ? null : (problem ?? this.problem),
    createdId: createdId ?? this.createdId,
  );

  @override
  List<Object?> get props => <Object?>[templates, busy, problem, createdId];
}

/// Создание проекта-инструкции: пустая, из фото или из встроенного шаблона.
class NewStepsCubit extends Cubit<NewStepsState> {
  NewStepsCubit({
    required CreateStepPattern create,
    required StepTemplateSource templates,
    required BookImageSource photos,
  }) : _create = create,
       _templates = templates,
       _photos = photos,
       super(const NewStepsState());

  final CreateStepPattern _create;
  final StepTemplateSource _templates;
  final BookImageSource _photos;

  Future<void> load() async {
    final Result<List<StepTemplate>> all = await _templates.all();
    if (!isClosed) {
      emit(state.copyWith(templates: all.valueOrNull ?? const <StepTemplate>[]));
    }
  }

  Future<void> createEmpty(String name) => _run(() => _create.empty(name: name));

  Future<void> fromTemplate(String name, String templateId) =>
      _run(() => _create.fromTemplate(name: name, templateId: templateId));

  /// [camera]: снять одно фото; иначе выбрать из галереи. Закрытый выбор (пустой список) ничего не делает.
  Future<void> fromPhotos(String name, {required bool camera}) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(busy: true, clearProblem: true));
    final Result<List<PickedBookFile>> picked = camera ? await _photos.takePhoto() : await _photos.pickPhotos();
    if (isClosed) {
      return;
    }
    if (picked.isFailure) {
      emit(state.copyWith(busy: false, problem: NewStepsProblem.photosFailed));
      return;
    }
    final List<Uint8List> bytes = <Uint8List>[for (final PickedBookFile f in picked.valueOrNull!) f.bytes];
    if (bytes.isEmpty) {
      emit(state.copyWith(busy: false));
      return;
    }
    emit(state.copyWith(busy: false));
    await _run(() => _create.fromPhotos(name: name, photos: bytes));
  }

  Future<void> _run(Future<Result<Project>> Function() action) async {
    if (state.busy) {
      return;
    }
    emit(state.copyWith(busy: true, clearProblem: true));
    final Result<Project> created = await action();
    if (isClosed) {
      return;
    }
    emit(
      created.isSuccess
          ? state.copyWith(busy: false, createdId: created.valueOrNull!.id)
          : state.copyWith(busy: false, problem: NewStepsProblem.createFailed),
    );
  }
}
