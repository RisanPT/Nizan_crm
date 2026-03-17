import 'package:flutter/material.dart';

/// Extension on [num] to easily create spacing elements
extension SpaceExtension on num {
  /// Returns a SizedBox with height equal to the number. Focuses on vertical spacing.
  /// Example: `16.h`
  SizedBox get h => SizedBox(height: toDouble());
  
  /// Returns a SizedBox with width equal to the number. Focuses on horizontal spacing.
  /// Example: `24.w`
  SizedBox get w => SizedBox(width: toDouble());
  
  /// Returns EdgeInsets with all sides equal to this number.
  /// Example: `Padding(padding: 16.p)`
  EdgeInsets get p => EdgeInsets.all(toDouble());
  
  /// Returns symmetric horizontal EdgeInsets.
  EdgeInsets get px => EdgeInsets.symmetric(horizontal: toDouble());
  
  /// Returns symmetric vertical EdgeInsets.
  EdgeInsets get py => EdgeInsets.symmetric(vertical: toDouble());
}
