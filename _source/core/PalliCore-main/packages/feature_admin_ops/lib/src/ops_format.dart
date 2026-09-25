String prettyDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String rupees(double value) {
  if (value >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(value >= 1000000 ? 1 : 1)}L';
  }
  return '₹${value.toStringAsFixed(0)}';
}
