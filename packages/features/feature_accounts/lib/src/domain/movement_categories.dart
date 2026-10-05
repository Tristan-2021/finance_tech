import 'transaction_type.dart';

/// Categorías de la demostración (valores tal como las guarda el backend).
const expenseCategories = ['comida', 'transporte', 'ocio', 'servicios', 'otros'];
const incomeCategories = ['ingreso', 'otros'];

List<String> categoriesFor(TransactionType type) =>
    type == TransactionType.debit ? expenseCategories : incomeCategories;
