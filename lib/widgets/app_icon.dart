import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum AppIconName {
  download,
  pdf,
  notification,
  close,
  add,
  check,
  calendar,
  chevronLeft,
  chevronRight,
  work,
  home,
  car,
  stop,
  route,
  edit,
  delete,
  warning,
  more,
  camera,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 24, this.color});

  final AppIconName name;
  final double size;
  final Color? color;

  String get _path => switch (name) {
    AppIconName.download => 'M5 20h14v-2H5v2zm7-3 7-7h-4V3H9v7H5l7 7z',
    AppIconName.pdf => 'M14 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V8l-6-6zm0 2.5L17.5 8H14V4.5zM18 20H6V4h6v6h6v10z',
    AppIconName.notification => 'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.1-1.6-5.7-4.5-6.4V4a1.5 1.5 0 0 0-3 0v.6C7.6 5.3 6 7.9 6 11v5l-2 2v1h16v-1l-2-2zm-2 0H8v-5c0-2.5 1.3-4.5 4-4.5s4 2 4 4.5v5z',
    AppIconName.close => 'M19 6.4 17.6 5 12 10.6 6.4 5 5 6.4l5.6 5.6L5 17.6 6.4 19l5.6-5.6 5.6 5.6 1.4-1.4-5.6-5.6L19 6.4z',
    AppIconName.add => 'M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z',
    AppIconName.check => 'M9 16.2 4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z',
    AppIconName.calendar => 'M19 4h-1V2h-2v2H8V2H6v2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V9h14v11zM7 11h4v4H7z',
    AppIconName.chevronLeft => 'M15.4 7.4 14 6l-6 6 6 6 1.4-1.4L10.8 12z',
    AppIconName.chevronRight => 'M8.6 6 7.2 7.4l4.6 4.6-4.6 4.6L8.6 18l6-6z',
    AppIconName.work => 'M20 6h-4V4c0-1.1-.9-2-2-2h-4C8.9 2 8 2.9 8 4v2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zM10 4h4v2h-4V4zm10 15H4V8h16v11zM9 11H7v2h2v-2zm8 0h-6v2h6v-2z',
    AppIconName.home => 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z',
    AppIconName.car => 'M18.9 6.5A2 2 0 0 0 17 5H7a2 2 0 0 0-1.9 1.5L3 13v8h2v-2h14v2h2v-8l-2.1-6.5zM7 7h10l1.3 4H5.7L7 7zm12 10H5v-4h14v4zm-11-3a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3zm8 0a1.5 1.5 0 1 0 0 3 1.5 1.5 0 0 0 0-3z',
    AppIconName.stop => 'M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10 10-4.5 10-10S17.5 2 12 2zm0 18a8 8 0 1 1 0-16 8 8 0 0 1 0 16zm-3-13h6v10H9z',
    AppIconName.route => 'M19 15.2V8.8a3 3 0 1 0-2 0v6.4a3 3 0 0 0 1 5.8 3 3 0 0 0 1-5.8zM18 5a1 1 0 1 1 0 2 1 1 0 0 1 0-2zm0 14a1 1 0 1 1 0-2 1 1 0 0 1 0 2zM6 3a3 3 0 0 0-1 5.8v6.4a3 3 0 1 0 2 0V8.8A3 3 0 0 0 6 3zm0 4a1 1 0 1 1 0-2 1 1 0 0 1 0 2zm0 12a1 1 0 1 1 0-2 1 1 0 0 1 0 2zm6-7a3 3 0 0 0-1 5.8v.2a1 1 0 0 1-1 1H9v2h1a3 3 0 0 0 3-3v-.2a3 3 0 0 0-1-5.8zm0 4a1 1 0 1 1 0-2 1 1 0 0 1 0 2z',
    AppIconName.edit => 'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z',
    AppIconName.delete => 'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z',
    AppIconName.warning => 'M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z',
    AppIconName.more => 'M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z',
    AppIconName.camera => 'M9 2 7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z',
  };

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#000000" d="$_path"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
