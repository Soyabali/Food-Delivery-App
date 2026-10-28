/// `₹525` for whole amounts, `₹915.00` when [decimals] is requested.
String rupees(num amount, {bool decimals = false}) {
  final negative = amount < 0;
  final abs = amount.abs();
  final text = decimals || abs % 1 != 0
      ? abs.toStringAsFixed(2)
      : abs.toStringAsFixed(0);
  return '${negative ? '-' : ''}₹$text';
}

String formatTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Just now", "5m ago", "2h ago", "Yesterday", "3d ago".
String formatRelative(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

String formatDate(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${t.day} ${months[t.month - 1]}, ${formatTime(t)}';
}
