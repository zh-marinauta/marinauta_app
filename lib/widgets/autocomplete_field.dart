import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AutoCompleteField extends StatefulWidget {
  final String label;
  final Function(String) onSelected;
  final String collection;
  final String searchField;
  final String displayField;
  final String? initialValue;
  final Color color;

  const AutoCompleteField({
    Key? key,
    required this.label,
    required this.onSelected,
    required this.collection,
    required this.searchField,
    required this.displayField,
    this.initialValue,
    this.color = const Color(0xFF00294D),
  }) : super(key: key);

  @override
  State<AutoCompleteField> createState() => _AutoCompleteFieldState();
}

class _AutoCompleteFieldState extends State<AutoCompleteField> {
  final TextEditingController _controller = TextEditingController();
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection(widget.collection)
        .where(widget.searchField, isGreaterThanOrEqualTo: query)
        .where(widget.searchField, isLessThanOrEqualTo: '$query\uf8ff')
        .limit(8)
        .get();

    final values =
        snapshot.docs.map((doc) => doc[widget.displayField].toString()).toList();

    setState(() => _results = values);
  }

  @override
  Widget build(BuildContext context) {
    final azul = widget.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          style: TextStyle(color: azul),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(color: azul),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: azul),
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: azul, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: _search,
        ),
        if (_results.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: azul.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _results.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final suggestion = _results[index];
                return ListTile(
                  title: Text(suggestion, style: TextStyle(color: azul)),
                  onTap: () {
                    _controller.text = suggestion;
                    widget.onSelected(suggestion);
                    setState(() => _results = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
