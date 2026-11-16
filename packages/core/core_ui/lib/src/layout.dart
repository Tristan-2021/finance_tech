import 'package:flutter/widgets.dart';

/// 화면 본문. 카드 사이 12px 간격으로 쌓습니다.
class FbView extends StatelessWidget {
  final List<Widget> children;

  const FbView({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _gap(children, 12),
    );
  }
}

/// 본문 영역을 [mobile] 순서로 한 줄에 쌓습니다.
class FbSplit extends StatelessWidget {
  final List<Widget> main;
  final List<Widget> side;
  final List<Widget>? mobile;

  const FbSplit({super.key, required this.main, required this.side, this.mobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _gap(mobile ?? [...main, ...side], 12),
    );
  }
}

List<Widget> _gap(List<Widget> items, double gap) => [
  for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
];
