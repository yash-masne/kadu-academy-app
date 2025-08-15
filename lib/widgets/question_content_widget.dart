// File: lib/widgets/question_content_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:kadu_academy_app/utils/text_formatter.dart'; // Import the utility file

class QuestionContentWidget extends StatelessWidget {
  final Map<String, dynamic> questionData;
  final int questionNumber;

  const QuestionContentWidget({
    Key? key,
    required this.questionData,
    required this.questionNumber,
  }) : super(key: key);

  Widget _buildScrollableLatex(String text, BuildContext context) {
    final textWidget = Math.tex(
      text,
      textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(),
      onErrorFallback: (FlutterMathException e) {
        return Text(
          '$text (LaTeX Error)',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.red),
        );
      },
    );

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.995, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: textWidget,
      ),
    );
  }

  Widget _buildTextWidget(String text, BuildContext context, bool isLatex) {
    if (isLatex) {
      return _buildScrollableLatex(text, context);
    } else {
      return RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyLarge,
          children: formatTextWithBold(text),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String questionText =
        questionData['questionText'] ?? 'No question text provided.';
    final String questionTextPart1 =
        questionData['questionTextPart1'] ?? questionText;
    final String questionTextPart2 = questionData['questionTextPart2'] ?? '';
    final bool isImageAboveQuestion =
        questionData['isImageAboveQuestion'] ?? false;
    final bool isImageInBetween = questionData['isImageInBetween'] ?? false;
    final String? questionImageUrl = questionData['imageUrl'];
    final bool isQuestionLatex = questionData['isLatexQuestion'] ?? false;

    List<Widget> content = [];

    if (isImageAboveQuestion &&
        questionImageUrl != null &&
        questionImageUrl.isNotEmpty) {
      content.add(
        Image.network(
          questionImageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) =>
              loadingProgress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) =>
              const Text('Error loading image'),
        ),
      );
      content.add(const SizedBox(height: 10));
      content.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextWidget(
                questionTextPart1,
                context,
                isQuestionLatex,
              ),
            ),
          ],
        ),
      );
    } else if (isImageInBetween &&
        questionImageUrl != null &&
        questionImageUrl.isNotEmpty) {
      content.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextWidget(
                questionTextPart1,
                context,
                isQuestionLatex,
              ),
            ),
          ],
        ),
      );
      content.add(const SizedBox(height: 10));
      content.add(
        Image.network(
          questionImageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) =>
              loadingProgress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
          errorBuilder: (context, error, stackTrace) =>
              const Text('Error loading image'),
        ),
      );
      if (questionTextPart2.isNotEmpty) {
        content.add(const SizedBox(height: 10));
        content.add(
          _buildTextWidget(questionTextPart2, context, isQuestionLatex),
        );
      }
    } else {
      content.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextWidget(questionText, context, isQuestionLatex),
            ),
          ],
        ),
      );
      if (questionImageUrl != null && questionImageUrl.isNotEmpty) {
        content.add(const SizedBox(height: 10));
        content.add(
          Image.network(
            questionImageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) =>
                loadingProgress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stackTrace) =>
                const Text('Error loading image'),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }
}
