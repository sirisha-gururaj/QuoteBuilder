// Data model for a single line item
class LineItem {
  String id;
  String name;
  double quantity;
  double rate;
  double discount;
  double taxPercent;
  double total; // This will be calculated

  LineItem({
    required this.id,
    this.name = '',
    this.quantity = 1,
    this.rate = 0,
    this.discount = 0,
    this.taxPercent = 0,
    this.total = 0,
  });
}