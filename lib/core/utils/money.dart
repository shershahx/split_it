/// Calculation boundary for the app's current two-decimal currencies.
///
/// Models and persistence remain doubles. Convert once on entry, calculate in
/// integer minor units, and convert back only for the public double APIs.
class Money {
  Money._();

  // Keeps cent values and their double round trips safe on native and web.
  static const int maxMinorUnits = 4503599627370495;

  /// Parses user input without first converting through a binary double.
  /// Scientific notation, grouping separators, signs and >2 decimals are not
  /// valid monetary input. Zero is allowed here; forms enforce positive amounts.
  static int parseAmount(String input) {
    final value = input.trim();
    if (value.length > 64 || !RegExp(r'^\d+(?:\.\d{0,2})?$').hasMatch(value)) {
      throw ArgumentError.value(
          input, 'amount', 'Use at most two decimal places');
    }
    final parts = value.split('.');
    final fraction = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
    final units =
        BigInt.parse(parts[0]) * BigInt.from(100) + BigInt.parse(fraction);
    if (units > BigInt.from(maxMinorUnits)) {
      throw ArgumentError.value(input, 'amount', 'Amount is too large');
    }
    return units.toInt();
  }

  static int toMinor(double amount) => toMinorUnits(amount);
  static double fromMinor(int units) => fromMinorUnits(units);
  static String formatMinor(int units) => formatMinorUnits(units);

  /// Currency code is supplied separately by the group, never inferred as USD.
  static String formatMinorUnits(int units) {
    _checkRange(units);
    final value = units.abs();
    return '${units < 0 ? '-' : ''}${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
  }

  /// Rounds the decimal representation of a nonnegative amount half up.
  /// For example, 1.005 becomes 101 cents; binary multiplication is not used.
  static int toMinorUnits(double amount) {
    final decimal = _MinorDecimal.fromAmount(amount);
    final units = decimal.rounded;
    if (units > BigInt.from(maxMinorUnits)) {
      throw ArgumentError.value(amount, 'amount', 'Amount is too large');
    }
    return units.toInt();
  }

  /// Converts a signed balance back to the existing public representation.
  static double fromMinorUnits(int units) {
    _checkRange(units);
    return units / 100;
  }

  static int add(int left, int right) {
    _checkRange(left);
    _checkRange(right);
    final result = left + right;
    _checkRange(result);
    return result;
  }

  static void _checkRange(int units) {
    if (units.abs() > maxMinorUnits) {
      throw ArgumentError.value(
        units,
        'units',
        'Minor-unit total is too large',
      );
    }
  }

  static void validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID must not be blank');
    }
  }

  /// Reject duplicates rather than silently losing a share in a map.
  static List<String> sortedMemberIds(List<String> memberIds) {
    final seen = <String>{};
    for (final id in memberIds) {
      validateUserId(id);
      if (!seen.add(id)) {
        throw ArgumentError.value(
          memberIds,
          'memberIds',
          'Duplicate member ID',
        );
      }
    }
    return seen.toList()..sort();
  }

  /// Equal shares, with leftover cents assigned by ascending user ID.
  /// Input order therefore never changes who receives the extra cent.
  static Map<String, int> splitEqually(double amount, List<String> memberIds) {
    final units = toMinorUnits(amount);
    final ids = sortedMemberIds(memberIds);
    if (ids.isEmpty) {
      throw ArgumentError.value(memberIds, 'memberIds', 'Members are required');
    }
    final base = units ~/ ids.length;
    final remainder = units % ids.length;
    return {
      for (var i = 0; i < ids.length; i++)
        ids[i]: base + (i < remainder ? 1 : 0),
    };
  }

  /// Normalizes persisted shares (including legacy fractional equal splits).
  ///
  /// The shares' decimal sum must round to the expense amount in cents.
  /// Largest fractional remainders receive leftover cents; ties use ascending
  /// user ID. This conserves the expense total rather than independently
  /// rounding each share and creating or losing cents.
  static Map<String, int> allocateShares(
    double amount,
    Map<String, double> shares,
  ) {
    final total = toMinorUnits(amount);
    if (shares.isEmpty) {
      throw ArgumentError.value(shares, 'shares', 'Shares are required');
    }
    final ids = sortedMemberIds(shares.keys.toList());
    final decimals = <String, _MinorDecimal>{};
    var denominator = BigInt.one;
    for (final id in ids) {
      toMinorUnits(shares[id]!); // Validate each amount and its range.
      final decimal = _MinorDecimal.fromAmount(shares[id]!);
      decimals[id] = decimal;
      if (decimal.denominator > denominator) {
        denominator = decimal.denominator;
      }
    }

    var sum = BigInt.zero;
    var allocated = 0;
    final result = <String, int>{};
    final remainders = <String, BigInt>{};
    for (final id in ids) {
      final decimal = decimals[id]!;
      final numerator =
          decimal.numerator * (denominator ~/ decimal.denominator);
      sum += numerator;
      final whole = (numerator ~/ denominator).toInt();
      allocated = add(allocated, whole);
      result[id] = whole;
      remainders[id] = numerator % denominator;
    }
    final roundedSum = (sum + denominator ~/ BigInt.two) ~/ denominator;
    if (roundedSum != BigInt.from(total)) {
      throw ArgumentError.value(
        shares,
        'shares',
        'Split total must equal the expense amount to the nearest cent',
      );
    }
    final ranked = ids.toList()
      ..sort((a, b) {
        final byRemainder = remainders[b]!.compareTo(remainders[a]!);
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });
    for (var i = 0; i < total - allocated; i++) {
      result[ranked[i]] = result[ranked[i]]! + 1;
    }
    return result;
  }
}

/// Exact decimal cents, using the double's shortest decimal representation.
class _MinorDecimal {
  final BigInt numerator;
  final BigInt denominator;

  _MinorDecimal(this.numerator, this.denominator);

  BigInt get rounded => (numerator + denominator ~/ BigInt.two) ~/ denominator;

  factory _MinorDecimal.fromAmount(double amount) {
    if (!amount.isFinite || amount < 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Amount must be finite and nonnegative',
      );
    }
    // Treat -0.0 as zero.
    final parts = (amount == 0 ? '0' : amount.toString()).split('e');
    final mantissa = parts[0].split('.');
    final fraction = mantissa.length == 2 ? mantissa[1] : '';
    final coefficient = BigInt.parse('${mantissa[0]}$fraction');
    final exponent = parts.length == 2 ? int.parse(parts[1]) : 0;
    final power = 2 + exponent - fraction.length;
    if (power >= 0) {
      return _MinorDecimal(
        coefficient * BigInt.from(10).pow(power),
        BigInt.one,
      );
    }
    return _MinorDecimal(coefficient, BigInt.from(10).pow(-power));
  }
}
