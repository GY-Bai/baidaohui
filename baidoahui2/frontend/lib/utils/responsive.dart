import 'package:flutter/material.dart';

class ResponsiveUtils {
  // 断点定义
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // 判断设备类型
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // 获取响应式列数
  static int getColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  // 获取响应式间距
  static double getSpacing(BuildContext context, {double mobile = 8.0, double tablet = 12.0, double desktop = 16.0}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  // 获取响应式字体大小
  static double getFontSize(BuildContext context, {double mobile = 14.0, double tablet = 16.0, double desktop = 18.0}) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  // 获取响应式内边距
  static EdgeInsets getPadding(BuildContext context, {
    EdgeInsets mobile = const EdgeInsets.all(8.0),
    EdgeInsets tablet = const EdgeInsets.all(12.0),
    EdgeInsets desktop = const EdgeInsets.all(16.0),
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }

  // 获取响应式容器宽度
  static double getContainerWidth(BuildContext context, {
    double mobileRatio = 1.0,
    double tabletRatio = 0.8,
    double desktopRatio = 0.6,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (isMobile(context)) return screenWidth * mobileRatio;
    if (isTablet(context)) return screenWidth * tabletRatio;
    return screenWidth * desktopRatio;
  }

  // 获取聊天模块高度
  static double getChatHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (isMobile(context)) return screenHeight * 0.4; // 移动端占40%
    return screenHeight * 0.6; // 桌面端占60%
  }

  // 获取订单详情高度
  static double getOrderDetailHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (isMobile(context)) return screenHeight * 0.5; // 移动端占50%
    return screenHeight * 0.7; // 桌面端占70%
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    DeviceType deviceType;
    
    if (ResponsiveUtils.isMobile(context)) {
      deviceType = DeviceType.mobile;
    } else if (ResponsiveUtils.isTablet(context)) {
      deviceType = DeviceType.tablet;
    } else {
      deviceType = DeviceType.desktop;
    }

    return builder(context, deviceType);
  }
}

enum DeviceType { mobile, tablet, desktop }

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        switch (deviceType) {
          case DeviceType.mobile:
            return mobile;
          case DeviceType.tablet:
            return tablet ?? desktop;
          case DeviceType.desktop:
            return desktop;
        }
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getColumns(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? mobileWidth;
  final double? tabletWidth;
  final double? desktopWidth;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.mobileWidth,
    this.tabletWidth,
    this.desktopWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    double? width;
    
    if (ResponsiveUtils.isMobile(context) && mobileWidth != null) {
      width = mobileWidth;
    } else if (ResponsiveUtils.isTablet(context) && tabletWidth != null) {
      width = tabletWidth;
    } else if (ResponsiveUtils.isDesktop(context) && desktopWidth != null) {
      width = desktopWidth;
    }

    return Container(
      width: width,
      padding: padding ?? ResponsiveUtils.getPadding(context),
      child: child,
    );
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double? mobileFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.mobileFontSize,
    this.tabletFontSize,
    this.desktopFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveUtils.getFontSize(
      context,
      mobile: mobileFontSize ?? 14.0,
      tablet: tabletFontSize ?? 16.0,
      desktop: desktopFontSize ?? 18.0,
    );

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
    );
  }
}

class ResponsiveSplitView extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double? splitRatio;

  const ResponsiveSplitView({
    super.key,
    required this.left,
    required this.right,
    this.splitRatio = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: Column(
        children: [
          Expanded(child: left),
          const Divider(height: 1),
          Expanded(child: right),
        ],
      ),
      desktop: Row(
        children: [
          Expanded(
            flex: (splitRatio! * 100).round(),
            child: left,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: ((1 - splitRatio!) * 100).round(),
            child: right,
          ),
        ],
      ),
    );
  }
} 