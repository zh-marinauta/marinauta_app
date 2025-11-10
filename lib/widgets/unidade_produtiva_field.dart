import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnidadeProdutivaField extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelected;
  final Color color;

  const UnidadeProdutivaField({
    Key? key,
    required this.onSelected,
    this.color = const Color(0xFF00294D),
  }) : super(key: key);

  @override
  State<UnidadeProdutivaField> createState() => _UnidadeProdutivaFieldState();
}

class _UnidadeProdutivaFieldState extends State<UnidadeProdutivaField> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];

  Future<void> _buscarUnidades(String query) async {
    if (query.isEmpty) {
      setState(() => _resultados = []);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('unidades_produtivas')
        .where('busca', arrayContains: query.toLowerCase())
        .limit(10)
        .get();

    final resultados = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();

    setState(() => _resultados = resultados);
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
            labelText: 'Unidade Produtiva (nome do pescador, barco ou comunidade)',
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
          onChanged: _buscarUnidades,
        ),
        if (_resultados.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: azul.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _resultados.length,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                final up = _resultados[index];
                final nome = up['unidade_produtiva'] ??
                    '${up['nome_pescador']} - ${up['nome_embarcacao']}';

                return ListTile(
                  title: Text(nome, style: TextStyle(color: azul)),
                  subtitle: Text(
                    '${up['comunidade']} - ${up['tipo_embarcacao']}',
                    style: TextStyle(color: azul.withOpacity(0.7)),
                  ),
                  onTap: () {
                    _controller.text = nome;
                    widget.onSelected(up);
                    setState(() => _resultados = []);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
