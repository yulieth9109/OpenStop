import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/models/answer.dart';
import '/view_models/questionnaire_provider.dart';
import '/widgets/animated_progress_bar.dart';
import '/widgets/question_inputs/question_input_view.dart';
import 'question_list.dart';
import 'question_navigation_bar.dart';
import 'question_text_header.dart';


class QuestionDialog extends StatefulWidget {
  final double maxHeightFactor;

  const QuestionDialog({
    required this.maxHeightFactor,
    Key? key
  }) : super(key: key);

  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}


class _QuestionDialogState extends State<QuestionDialog> {
  // This is used in lower widgets to get notified whenever the current answer changes.
  // In contrast to the answer of the QuestionnaireProvider which is only updated if the user
  // presses one of the navigation buttons, this is updated every time the answer value changes.
  // This can happen quite often, especially in the Duration picker, hence the separation.
  final _answer = ValueNotifier<Answer?>(null);

  Key? _questionnaireKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final questionnaire = context.read<QuestionnaireProvider>();
    // This is required so the current stored answer is cleared whenever the questionnaire changes
    if (questionnaire.key != _questionnaireKey) {
      _answer.value = null;
      _questionnaireKey = questionnaire.key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionnaire = context.watch<QuestionnaireProvider>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOutCubicEmphasized,
      switchOutCurve: Curves.ease,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          )
        );
      },
      child: !questionnaire.hasEntries
        ? null
        : ValueListenableProvider<Answer?>.value(
          // add key so changes of the underlying questionnaire will be animated
          key: _questionnaireKey,
          value: _answer,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: widget.maxHeightFactor,
              child: Column(
                children: [
                  Flexible(
                    child: QuestionList(
                      index: questionnaire.activeIndex!,
                      children: List.generate(
                        questionnaire.length!,
                        (index) {
                          final questionnaireEntry = questionnaire.entries![index];

                          return ColoredBox(
                            key: ValueKey(questionnaireEntry.question),
                            color: Colors.white,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  QuestionTextHeader(
                                    question: questionnaireEntry.question.question,
                                    details: questionnaireEntry.question.description,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: 20,
                                      left: 20,
                                      bottom: 30
                                    ),
                                    child: QuestionInputView.fromQuestionInput(
                                      questionnaireEntry.question.input,
                                      onChange: _handleChange
                                    )
                                  )
                                ],
                              )
                            )
                          );
                        },
                        growable: false
                      )
                    )
                  ),
                  AnimatedProgressBar(
                    minHeight: 1,
                    color: Theme.of(context).colorScheme.primary,
                    value: (questionnaire.activeIndex!) / questionnaire.length!,
                    // cannot use transparent color here otherwise the map widget behind will become slightly visible
                    backgroundColor: const Color(0xFFEEEEEE)
                  ),
                  QuestionNavigationBar(
                    onNext: _handleNext,
                    onBack: _handleBack,
                  )
                ],
              )
            )
          )
        )
    );
  }


  // ignore: use_setters_to_change_properties
  void _handleChange(Answer? answer) {
    _answer.value = answer;
  }


  void _handleBack() {
    _update(goBack: true);
  }


  void _handleNext() {
    _update();
  }


  void _update({bool goBack = false}) {
    final questionnaire = context.read<QuestionnaireProvider>();
    debugPrint('Previous Answer: ${_answer.value?.answer}');
    questionnaire.update(_answer.value);
    goBack ? questionnaire.previous() : questionnaire.next();
    _answer.value = questionnaire.activeEntry?.answer;
    debugPrint('Current Answer: ${_answer.value?.answer}');
    // always onfocus the current node to close all onscreen keyboards
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
