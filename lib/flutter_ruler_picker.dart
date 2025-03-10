library ruler_picker;

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// a triangle painter
class _TrianglePainter extends CustomPainter {
  // final double lineSize;

  // _TrianglePainter({this.lineSize = 16});
  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, tan(pi / 3) * size.width / 2);
    path.close();
    Paint paint = Paint();
    paint.color = const Color.fromARGB(255, 118, 165, 248);
    paint.style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

/// The controller for the ruler picker
/// init the ruler value from the controller
/// 用于 RulerPicker 的控制器，可以在构造函数里初始化默认值
class RulerPickerController extends ValueNotifier<num> {
  RulerPickerController({num value = 0}) : super(value);

  num get value => super.value;

  set value(num newValue) {
    super.value = newValue;
  }
}

typedef void ValueChangedCallback(num value);

/// RulerPicker 标尺选择器
/// [width] 必须是具体的值，包括父级container的width，不能是 double.infinity，
/// 可以传入MediaQuery.of(context).size.width
class RulerPicker extends StatefulWidget {
  final ValueChangedCallback onValueChanged;
  final String Function(int index, num rulerScaleValue) onBuildRulerScaleText;
  final double width;
  final double height;
  final TextStyle rulerScaleTextStyle;
  final List<ScaleLineStyle> scaleLineStyleList;
  final List<RulerRange> ranges;
  final Widget? marker;
  final double rulerMarginTop;
  final Color rulerBackgroundColor;
  final RulerPickerController? controller;
  final Color selectedRangeColor; // 添加选中区域的颜色属性
  final num? referenceValue; // 添加参考值属性

  RulerPicker({
    required this.onValueChanged,
    required this.width,
    required this.height,
    required this.onBuildRulerScaleText,
    this.ranges = const [],
    this.rulerMarginTop = 0,
    this.scaleLineStyleList = const [
      ScaleLineStyle(
          scale: 0,
          color: Color.fromARGB(255, 188, 194, 203),
          width: 2,
          height: 32),
      ScaleLineStyle(
          color: Color.fromARGB(255, 188, 194, 203), width: 1, height: 20),
    ],
    this.rulerScaleTextStyle = const TextStyle(
      color: Color.fromARGB(255, 188, 194, 203),
      fontSize: 14,
    ),
    this.marker,
    this.rulerBackgroundColor = Colors.white,
    this.controller,
    this.selectedRangeColor = const Color.fromRGBO(200, 200, 200, 0.3), // 默认为半透明灰色
    this.referenceValue,
  });

  @override
  State<StatefulWidget> createState() {
    return RulerPickerState();
  }
}

class RulerPickerState extends State<RulerPicker> {
  double lastOffset = 0;
  bool isPosFixed = false;
  String value = '';
  late ScrollController scrollController;
  Map<int, ScaleLineStyle> _scaleLineStyleMap = {};
  int itemCount = 0;

  // 添加变量跟踪参考值和当前值
  num _referenceValue = 0;
  num _currentValue = 0;
  // 添加标志，表示参考值是否已经初始化
  bool _isReferenceValueInitialized = false;

  @override
  void initState() {
    super.initState();

    itemCount = _calculateItemCount();
    print(itemCount);

    widget.scaleLineStyleList.forEach((element) {
      _scaleLineStyleMap[element.scale] = element;
    });
    
    // 初始化参考值和当前值
    _referenceValue = widget.referenceValue ?? widget.controller?.value ?? 0;
    _currentValue = widget.controller?.value ?? 0;
    
    // 如果提供了referenceValue，则标记为已初始化
    _isReferenceValueInitialized = widget.referenceValue != null;

    double initValueOffset = getPositionByValue(widget.controller?.value ?? 0);

    scrollController = ScrollController(
        initialScrollOffset: initValueOffset > 0 ? initValueOffset : 0);

    scrollController.addListener(_onValueChanged);

    widget.controller?.addListener(() {
      setState(() {
        _currentValue = widget.controller?.value ?? 0;
      });
      setPositionByValue(widget.controller?.value ?? 0);
    });
  }

  int _calculateItemCount() {
    int itemCount = 0;
    widget.ranges.forEach((element) {
      // print(element.end);
      itemCount += ((element.end - element.begin) / element.scale).truncate();
    });
    itemCount += 1;
    return itemCount;
  }

  void _onValueChanged() {
    int currentIndex = scrollController.offset ~/ _ruleScaleInterval.toInt();

    if (currentIndex < 0) currentIndex = 0;
    num currentValue = getRulerScaleValue(currentIndex);

    var lastConfig = widget.ranges.last;
    if (currentValue > lastConfig.end) currentValue = lastConfig.end;

    setState(() {
      _currentValue = currentValue;
    });

    widget.onValueChanged(currentValue);
  }

  /// default mark
  Widget _buildMark() {
    /// default mark arrow
    Widget triangle() {
      return SizedBox(
        width: 15,
        height: 15,
        child: CustomPaint(
          painter: _TrianglePainter(),
        ),
      );
    }

    return Container(
      child: SizedBox(
        width: _ruleScaleInterval * 2,
        height: 45,
        child: Stack(
          children: <Widget>[
            Align(alignment: Alignment.topCenter, child: triangle()),
            Align(
                child: Container(
                  width: 3,
                  height: 34,
                  color: Color.fromARGB(255, 118, 165, 248),
                )),
          ],
        ),
      ),
    );
  }

  ///绘制刻度线
  Widget _buildRulerScaleLine(int index) {
    double width = 0;
    double height = 0;
    Color color = Color.fromARGB(255, 188, 194, 203);
    int scale = index % 10;

    if (_scaleLineStyleMap[scale] != null) {
      width = _scaleLineStyleMap[scale]!.width;
      height = _scaleLineStyleMap[scale]!.height;
      color = _scaleLineStyleMap[scale]!.color;
    } else {
      if (_scaleLineStyleMap[-1] != null) {
        scale = -1;
        width = _scaleLineStyleMap[scale]!.width;
        height = _scaleLineStyleMap[scale]!.height;
        color = _scaleLineStyleMap[scale]!.color;
      } else {
        if (scale == 0) {
          width = 2;
          height = 32;
        } else {
          width = 1;
          height = 20;
        }
      }
    }

    return Container(
      width: width,
      height: height,
      color: color,
    );
  }

  Widget _buildRulerScale(BuildContext context, int index) {
    return Container(
        width: _ruleScaleInterval,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 刻度线改为底部对齐
            Align(
                alignment: Alignment.bottomCenter,
                child: _buildRulerScaleLine(index)),
            // 文本放在上方
            Positioned(
              top: 5, // 从底部改为顶部
              width: 100,
              left: -50 + _ruleScaleInterval / 2,
              child: index % 10 == 0
                  ? Container(
                alignment: Alignment.center,
                child: Text(
                  widget.onBuildRulerScaleText(
                      index, getRulerScaleValue(index)),
                  style: widget.rulerScaleTextStyle,
                ),
              )
                  : SizedBox(),
            )
          ],
        )
    );
  }

  //尺子刻度间隔
  final double _ruleScaleInterval = 10;

//使得尺子刻度和指示器对齐
  void fixOffset() {
    int tempFixedOffset = (scrollController.offset + 0.5) ~/ 1;

    double fixedOffset = (tempFixedOffset + _ruleScaleInterval / 2) ~/
        _ruleScaleInterval.toInt() *
        _ruleScaleInterval;
    Future.delayed(Duration.zero, () {
      scrollController.animateTo(fixedOffset,
          duration: Duration(milliseconds: 50), curve: Curves.bounceInOut);
    });
  }

  ///获取尺子的刻度值
  num getRulerScaleValue(int index) {
    num rulerScaleValue = 0;

    RulerRange? currentConfig;
    for (RulerRange config in widget.ranges) {
      currentConfig = config;
      if (currentConfig == widget.ranges.last) {
        break;
      }
      var totalCount = ((config.end - config.begin) / config.scale).truncate();

      if (index <= totalCount) {
        break;
      } else {
        index -= totalCount;
      }
    }

    rulerScaleValue = index * currentConfig!.scale + currentConfig!.begin;

    return rulerScaleValue;
  }

  /// 从滚动偏移量直接计算值
  num getRulerValueFromOffset(double offset) {
    int index = offset ~/ _ruleScaleInterval.toInt();
    if (index < 0) index = 0;
    
    num value = getRulerScaleValue(index);
    var lastConfig = widget.ranges.last;
    if (value > lastConfig.end) value = lastConfig.end;
    
    return value;
  }

  @override
  Widget build(BuildContext context) {
    // 获取安全的scrollOffset值
    double safeScrollOffset = 0.0;
    try {
      if (scrollController.hasClients) {
        safeScrollOffset = scrollController.offset;
      }
    } catch (e) {
      // 如果发生异常，使用默认值0.0
    }

    return Container(
      margin: EdgeInsets.only(),
      width: widget.width,
      height: widget.height + widget.rulerMarginTop,
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.bottomCenter,
            child: Listener(
              onPointerDown: (event) {
                FocusScope.of(context).requestFocus(new FocusNode());
                isPosFixed = false;
                
                // 只有在第一次触摸且未设置参考值时初始化
                if (!_isReferenceValueInitialized) {
                  setState(() {
                    _referenceValue = _currentValue;
                    _isReferenceValueInitialized = true;
                  });
                }
              },
              onPointerUp: (event) {},
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    // 强制重绘以更新选中区域
                    setState(() {});
                  } else if (scrollNotification is ScrollEndNotification) {
                    if (!isPosFixed) {
                      isPosFixed = true;
                      fixOffset();
                    }
                  }
                  return true;
                },
                child: Container(
                  width: double.infinity,
                  height: widget.height,
                  color: widget.rulerBackgroundColor,
                  child: Stack(
                    children: [
                      // 选中区域
                      if (_referenceValue != _currentValue)
                        CustomPaint(
                          size: Size(widget.width, widget.height),
                          painter: _SelectedRangePainter(
                            scrollOffset: safeScrollOffset,
                            referenceValue: _referenceValue,
                            currentValue: _currentValue,
                            getPositionByValue: getPositionByValue,
                            selectedRangeColor: widget.selectedRangeColor,
                            leftPadding: (widget.width - _ruleScaleInterval) / 2,
                            ruleScaleInterval: _ruleScaleInterval,
                            scrollController: scrollController,
                            getRulerValueFromOffset: getRulerValueFromOffset,
                            ranges: widget.ranges,
                          ),
                          isComplex: true,
                          willChange: true,
                        ),

                      // ListView
                      ListView.builder(
                        padding: EdgeInsets.only(
                          left: (widget.width - _ruleScaleInterval) / 2,
                          right: (widget.width - _ruleScaleInterval) / 2,
                        ),
                        itemExtent: _ruleScaleInterval,
                        itemCount: itemCount,
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        itemBuilder: _buildRulerScale,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: widget.marker ?? _buildMark(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  void didUpdateWidget(RulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (mounted) {
      if (isRangesChanged(oldWidget)) {
        Future.delayed(Duration.zero, () {
          setState(() {
            itemCount = _calculateItemCount();
          });
          _onValueChanged();
        });
      }

      // 如果参考值发生变化，则更新参考值
      if (widget.referenceValue != oldWidget.referenceValue && widget.referenceValue != null) {
        setState(() {
          _referenceValue = widget.referenceValue!;
          _isReferenceValueInitialized = true;
        });
      }
    }
  }

  bool isRangesChanged(RulerPicker oldWidget) {
    if (oldWidget.ranges.length != widget.ranges.length) {
      return true;
    }

    if (widget.ranges.isEmpty) return false;
    for (int i = 0; i < widget.ranges.length; i++) {
      RulerRange oldRange = oldWidget.ranges[i];
      RulerRange range = widget.ranges[i];
      if (oldRange.begin != range.begin ||
          oldRange.end != range.end ||
          oldRange.scale != range.scale) {
        return true;
      }
    }
    return false;
  }

  double getPositionByValue(num value) {
    double offsetValue = 0;
    for (RulerRange config in widget.ranges) {
      if (config.begin <= value && config.end >= value) {
        offsetValue +=
            ((value - config.begin) / config.scale) * _ruleScaleInterval;
        break;
      } else if (value >= config.begin) {
        var totalCount =
        ((config.end - config.begin) / config.scale).truncate();
        offsetValue += totalCount * _ruleScaleInterval;
      }
    }
    return offsetValue;
  }

  /// 根据数值设置标记位置
  void setPositionByValue(num value) {
    double offsetValue = getPositionByValue(value);
    scrollController.jumpTo(offsetValue);
    fixOffset();
  }
}

class ScaleLineStyle {
  final int scale;
  final Color color;
  final double width;
  final double height;

  const ScaleLineStyle({
    this.scale = -1,
    required this.color,
    required this.width,
    required this.height,
  });
}

class RulerRange {
  final double scale;
  final int begin;
  final int end;

  const RulerRange({
    required this.begin,
    required this.end,
    this.scale = 1,
  });
}

// 重新实现选中区域绘制器，确保参考值位置固定对齐
class _SelectedRangePainter extends CustomPainter {
  final double scrollOffset;
  final num referenceValue;
  final num currentValue;
  final Function(num) getPositionByValue;
  final Color selectedRangeColor;
  final double leftPadding;
  final double ruleScaleInterval;
  final ScrollController scrollController;
  final Function(double) getRulerValueFromOffset;
  final List<RulerRange> ranges;

  _SelectedRangePainter({
    required this.scrollOffset,
    required this.referenceValue,
    required this.currentValue,
    required this.getPositionByValue,
    required this.selectedRangeColor,
    required this.leftPadding,
    required this.ruleScaleInterval,
    required this.scrollController,
    required this.getRulerValueFromOffset,
    required this.ranges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (referenceValue == currentValue && !scrollController.hasClients) {
      return;
    }

    // 获取当前滚动位置
    double currentScrollOffset = scrollController.hasClients ? scrollController.offset : scrollOffset;
    
    // 计算参考值位置，使用确定的方式，不再动态调整
    double referenceExactPos = getPositionByValue(referenceValue);
    
    // 视图中心位置（标记位置）
    double centerPos = size.width / 2;
    
    // 计算参考值在视图中的位置，采用固定方式
    double refPosInView = leftPadding + (referenceExactPos - currentScrollOffset);
    
    // 精确修正参考值位置，确保对准刻度线中心
    double scaleHalfWidth = ruleScaleInterval / 2;
    double adjustedRefPosInView = ((refPosInView + scaleHalfWidth) / ruleScaleInterval).floor() 
        * ruleScaleInterval + scaleHalfWidth;
    
    // 计算选中区域边界
    double left = min(adjustedRefPosInView, centerPos);
    double right = max(adjustedRefPosInView, centerPos);
    
    // // 特殊处理边界情况
    // if (referenceValue == ranges.first.begin && left < leftPadding) {
    //   left = leftPadding;
    // }
    
    // 避免区域超出可见范围
    if (right <= 0 || left >= size.width) {
      return;
    }
    
    // 确保在可见区域内
    left = max(0, left);
    right = min(size.width, right);
    
    // 绘制区域
    Paint paint = Paint()
      ..color = selectedRangeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    
    canvas.drawRect(
      Rect.fromLTRB(left, 0, right, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SelectedRangePainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset || 
           (scrollController.hasClients && scrollController.position.isScrollingNotifier.value);
  }
}
