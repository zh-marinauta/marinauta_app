import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ColetaScreen extends StatefulWidget {
  final String coletorEmail;
  final String municipio;
  final String entreposto;

  const ColetaScreen({
    super.key,
    required this.coletorEmail,
    required this.municipio,
    required this.entreposto,
  });

  @override
  State<ColetaScreen> createState() => _ColetaScreenState();
}

class _ColetaScreenState extends State<ColetaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores gerais
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _horaController = TextEditingController();
  final TextEditingController _localController = TextEditingController();

  // Unidade Produtiva
  final TextEditingController _buscaUnidadeController = TextEditingController();
  final TextEditingController _pescadorController = TextEditingController();
  final TextEditingController _embarcacaoController = TextEditingController();
  final TextEditingController _tipoEmbarcacaoController =
      TextEditingController();
  final TextEditingController _categoriaEmbarcacaoController =
      TextEditingController();
  final TextEditingController _comunidadeController = TextEditingController();

  String? unidadeProdutivaSelecionada;
  String? unidadeProdutivaId;
  String origemProducao = "Própria";

  List<Map<String, dynamic>> especiesRegistradas = [];
  List<Map<String, dynamic>> sugestoesUnidades = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataController.text = DateFormat('dd/MM/yyyy').format(now);
    _horaController.text = DateFormat('HH:mm').format(now);
    _localController.text = widget.entreposto;
  }

  // 🔹 Busca unidades produtivas existentes
  Future<void> _buscarUnidadesProdutivas(String termo) async {
    if (termo.length < 3) return;
    final query = await _firestore.collection('unidades_produtivas').get();
    final resultados = query.docs
        .where(
          (d) => d['unidade_produtiva'].toString().toLowerCase().contains(
            termo.toLowerCase(),
          ),
        )
        .map((d) => {'id': d.id, ...d.data()})
        .toList();

    setState(() {
      sugestoesUnidades = resultados.cast<Map<String, dynamic>>();
    });
  }

  void _selecionarUnidade(Map<String, dynamic> unidade) {
    setState(() {
      unidadeProdutivaSelecionada = unidade['unidade_produtiva'];
      unidadeProdutivaId = unidade['id'];
      _buscaUnidadeController.text = unidade['unidade_produtiva'];
      _pescadorController.text = unidade['pescador'] ?? '';
      _embarcacaoController.text = unidade['embarcacao'] ?? '';
      _tipoEmbarcacaoController.text = unidade['tipo_embarcacao'] ?? '';
      _categoriaEmbarcacaoController.text =
          unidade['categoria_embarcacao'] ?? '';
      _comunidadeController.text = unidade['comunidade'] ?? '';
      sugestoesUnidades.clear();
    });
  }

  // 🔹 Snapshot da versão anterior (como antes)
  Future<void> _snapshotVersaoAnterior(
    String docId,
    Map<String, dynamic> dados,
  ) async {
    final versaoAtual = (dados['versao'] ?? 1) as int;
    await _firestore
        .collection('unidades_produtivas')
        .doc(docId)
        .collection('versoes')
        .add({
          'versao': versaoAtual,
          'dados': dados,
          'salvo_em': DateTime.now().toIso8601String(),
        });
  }

  // 🔹 Atualização branda de unidades produtivas (mantém versão branda)
  Future<void> _verificarOuAtualizarUnidadeProdutiva() async {
    final nome = _pescadorController.text.trim();
    final barco = _embarcacaoController.text.trim();
    final tipo = _tipoEmbarcacaoController.text.trim();
    final categoria = _categoriaEmbarcacaoController.text.trim();
    final comunidade = _comunidadeController.text.trim();
    final upConcat = "$nome - $barco - $comunidade - $tipo - $categoria";

    if (unidadeProdutivaId == null) {
      final created = await _firestore.collection('unidades_produtivas').add({
        'unidade_produtiva': upConcat,
        'pescador': nome,
        'embarcacao': barco,
        'tipo_embarcacao': tipo,
        'categoria_embarcacao': categoria,
        'comunidade': comunidade,
        'municipio': widget.municipio,
        'entrepostos': [widget.entreposto],
        'ativo': true,
        'versao': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
      unidadeProdutivaId = created.id;
      unidadeProdutivaSelecionada = upConcat;
      return;
    }

    final docRef = _firestore
        .collection('unidades_produtivas')
        .doc(unidadeProdutivaId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final dados = doc.data()!;
    final atualNome = (dados['pescador'] ?? '').toString();
    final atualBarco = (dados['embarcacao'] ?? '').toString();
    final atualTipo = (dados['tipo_embarcacao'] ?? '').toString();
    final atualCat = (dados['categoria_embarcacao'] ?? '').toString();
    final atualCom = (dados['comunidade'] ?? '').toString();

    bool willUpdate = false;
    bool willCreateNew = false;

    final changedCore =
        (atualNome.isNotEmpty && atualNome != nome) ||
        (atualBarco.isNotEmpty && atualBarco != barco) ||
        (atualTipo.isNotEmpty && atualTipo != tipo);

    final changedCompl =
        (atualCat.isNotEmpty && atualCat != categoria) ||
        (atualCom.isNotEmpty && atualCom != comunidade);

    final filledEmpty =
        (atualTipo.isEmpty && tipo.isNotEmpty) ||
        (atualCat.isEmpty && categoria.isNotEmpty) ||
        (atualCom.isEmpty && comunidade.isNotEmpty);

    if (changedCore || changedCompl) {
      willCreateNew = true;
    } else if (filledEmpty) {
      willUpdate = true;
    }

    if (willCreateNew) {
      await _firestore.collection('unidades_produtivas').add({
        'unidade_produtiva': upConcat,
        'pescador': nome,
        'embarcacao': barco,
        'tipo_embarcacao': tipo,
        'categoria_embarcacao': categoria,
        'comunidade': comunidade,
        'municipio': widget.municipio,
        'entrepostos': [widget.entreposto],
        'ativo': true,
        'versao': 1,
        'criado_em': DateTime.now().toIso8601String(),
      });
    } else if (willUpdate) {
      await _snapshotVersaoAnterior(doc.id, dados);
      final versaoNova = (dados['versao'] ?? 1) + 1;
      await docRef.update({
        'tipo_embarcacao': atualTipo.isEmpty ? tipo : atualTipo,
        'categoria_embarcacao': atualCat.isEmpty ? categoria : atualCat,
        'comunidade': atualCom.isEmpty ? comunidade : atualCom,
        'versao': versaoNova,
        'atualizado_em': DateTime.now().toIso8601String(),
      });
    }

    unidadeProdutivaSelecionada = upConcat;
  }

  // 🔹 Salvar desembarque
  Future<void> _salvarDesembarque() async {
    if (especiesRegistradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos uma espécie.')),
      );
      return;
    }

    await _verificarOuAtualizarUnidadeProdutiva();

    final novoDesembarque = {
      'data': _dataController.text,
      'hora': _horaController.text,
      'coletor': widget.coletorEmail,
      'municipio': widget.municipio,
      'entreposto': widget.entreposto,
      'local': _localController.text,
      'unidade_produtiva': unidadeProdutivaSelecionada,
      'pescador': _pescadorController.text,
      'embarcacao': _embarcacaoController.text,
      'tipo_embarcacao': _tipoEmbarcacaoController.text,
      'categoria_embarcacao': _categoriaEmbarcacaoController.text,
      'comunidade': _comunidadeController.text,
      'origem_producao': origemProducao,
      'timestamp': DateTime.now().toIso8601String(),
      'especies': especiesRegistradas,
    };

    await _firestore.collection('desembarques').add(novoDesembarque);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Desembarque salvo com sucesso!')),
    );

    await Future.delayed(const Duration(milliseconds: 600));
    if (context.mounted) Navigator.pushReplacementNamed(context, '/dashboard');
  }

  // 🔹 Interface
  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF00294D);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: azul,
        title: const Text('Registro de Desembarque'),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buscar Unidade Produtiva',
              style: TextStyle(color: azul, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _buscaUnidadeController,
              style: TextStyle(color: azul),
              decoration: InputDecoration(
                labelText: 'Digite parte do nome, barco ou comunidade',
                labelStyle: TextStyle(color: azul),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: azul),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: azul),
                ),
              ),
              onChanged: _buscarUnidadesProdutivas,
            ),
            if (sugestoesUnidades.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: azul),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Column(
                  children: sugestoesUnidades
                      .map(
                        (u) => ListTile(
                          title: Text(
                            u['unidade_produtiva'],
                            style: TextStyle(color: azul),
                          ),
                          onTap: () => _selecionarUnidade(u),
                        ),
                      )
                      .toList(),
                ),
              ),

            const SizedBox(height: 16),

            Text(
              'Dados da Unidade Produtiva',
              style: TextStyle(color: azul, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTextField('Pescador', _pescadorController, azul),
            const SizedBox(height: 8),
            _buildTextField('Embarcação', _embarcacaoController, azul),
            const SizedBox(height: 8),
            _buildTextField(
              'Tipo de embarcação',
              _tipoEmbarcacaoController,
              azul,
            ),
            const SizedBox(height: 8),
            _buildTextField(
              'Categoria da embarcação',
              _categoriaEmbarcacaoController,
              azul,
            ),
            const SizedBox(height: 8),
            _buildTextField('Comunidade', _comunidadeController, azul),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: origemProducao,
              items: [
                'Própria',
                'De terceiros',
                'Ambas',
              ].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              decoration: InputDecoration(
                labelText: 'Origem da produção',
                labelStyle: TextStyle(color: azul),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: azul),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: azul),
                ),
              ),
              onChanged: (v) => setState(() => origemProducao = v!),
            ),

            const Divider(height: 24, color: Colors.black26),

            ...especiesRegistradas.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Card(
                child: ListTile(
                  title: Text(
                    '${e['especie']} - ${e['quantidade']} ${e['unidade']}',
                    style: TextStyle(color: azul),
                  ),
                  subtitle: Text(
                    'Pesqueiro: ${e['pesqueiro']} | R\$${e['preco_unidade']}/un',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () =>
                        setState(() => especiesRegistradas.removeAt(i)),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _mostrarDialogoAdicionarEspecie(context),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Espécie'),
            ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _salvarDesembarque,
                style: ElevatedButton.styleFrom(backgroundColor: azul),
                child: const Text(
                  'Salvar Desembarque',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color azul, {
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: azul),
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: azul),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: azul)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: azul)),
      ),
    );
  }

  /// ======================================
  // FUNÇÕES DE AUTOCOMPLETE E AUTOCRIAÇÃO
  // ======================================
  Future<List<String>> _buscarSugestoes(String colecao, String termo) async {
    if (termo.length < 2) return [];
    final snap = await _firestore.collection(colecao).get();
    return snap.docs
        .map((d) => d['nome'].toString())
        .where((n) => n.toLowerCase().contains(termo.toLowerCase()))
        .toList();
  }

  /// Garante que o item existe na coleção, criando se não existir.
  Future<void> _garantirRegistroColecao(String colecao, String nome) async {
    if (nome.trim().isEmpty) return;
    final query = await _firestore
        .collection(colecao)
        .where('nome', isEqualTo: nome.trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      await _firestore.collection(colecao).add({
        'nome': nome.trim(),
        'ativo': true,
        'criado_em': DateTime.now().toIso8601String(),
      });
    }
  }

  // ======================================
  // DIALOGO PARA ADICIONAR ESPÉCIE
  // ======================================
  Future<void> _mostrarDialogoAdicionarEspecie(BuildContext context) async {
    const azul = Color(0xFF00294D);
    final especieCtrl = TextEditingController();
    final qtdCtrl = TextEditingController();
    final precoCtrl = TextEditingController();
    final arteCtrl = TextEditingController();
    final pesqueiroCtrl = TextEditingController();
    String unidade = 'Kg';

    List<String> sugestoesEspecie = [];
    List<String> sugestoesArte = [];
    List<String> sugestoesPesqueiro = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Adicionar Espécie'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Campo de Espécie com autocomplete
                  TextField(
                    controller: especieCtrl,
                    style: const TextStyle(color: azul),
                    decoration: const InputDecoration(
                      labelText: 'Espécie',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) async {
                      final results = await _buscarSugestoes('especies', v);
                      setStateDialog(() => sugestoesEspecie = results);
                    },
                  ),
                  if (sugestoesEspecie.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: azul),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: sugestoesEspecie
                            .map(
                              (s) => ListTile(
                                title: Text(s),
                                onTap: () {
                                  especieCtrl.text = s;
                                  setStateDialog(
                                    () => sugestoesEspecie.clear(),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Quantidade
                  _buildTextField('Quantidade', qtdCtrl, azul),
                  const SizedBox(height: 8),

                  // Unidade
                  DropdownButtonFormField<String>(
                    value: unidade,
                    items: ['Kg', 'Dúzia', 'Caixa']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => unidade = v!,
                    decoration: const InputDecoration(
                      labelText: 'Unidade de medida',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Preço
                  _buildTextField('Preço por unidade (R\$)', precoCtrl, azul),
                  const SizedBox(height: 8),

                  // Arte de pesca com autocomplete
                  TextField(
                    controller: arteCtrl,
                    style: const TextStyle(color: azul),
                    decoration: const InputDecoration(
                      labelText: 'Arte de pesca',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) async {
                      final results = await _buscarSugestoes('artes_pesca', v);
                      setStateDialog(() => sugestoesArte = results);
                    },
                  ),
                  if (sugestoesArte.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: azul),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: sugestoesArte
                            .map(
                              (s) => ListTile(
                                title: Text(s),
                                onTap: () {
                                  arteCtrl.text = s;
                                  setStateDialog(() => sugestoesArte.clear());
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Pesqueiro com autocomplete
                  TextField(
                    controller: pesqueiroCtrl,
                    style: const TextStyle(color: azul),
                    decoration: const InputDecoration(
                      labelText: 'Pesqueiro',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) async {
                      final results = await _buscarSugestoes('pesqueiros', v);
                      setStateDialog(() => sugestoesPesqueiro = results);
                    },
                  ),
                  if (sugestoesPesqueiro.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: azul),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: sugestoesPesqueiro
                            .map(
                              (s) => ListTile(
                                title: Text(s),
                                onTap: () {
                                  pesqueiroCtrl.text = s;
                                  setStateDialog(
                                    () => sugestoesPesqueiro.clear(),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: azul),
                onPressed: () async {
                  // 🔹 Autoalimentar coleções
                  await _garantirRegistroColecao('especies', especieCtrl.text);
                  await _garantirRegistroColecao('artes_pesca', arteCtrl.text);
                  await _garantirRegistroColecao(
                    'pesqueiros',
                    pesqueiroCtrl.text,
                  );

                  // 🔹 Adicionar à lista local
                  setState(() {
                    especiesRegistradas.add({
                      'especie': especieCtrl.text.trim(),
                      'quantidade': double.tryParse(qtdCtrl.text) ?? 0,
                      'unidade': unidade,
                      'preco_unidade': double.tryParse(precoCtrl.text) ?? 0,
                      'arte_pesca': arteCtrl.text.trim(),
                      'pesqueiro': pesqueiroCtrl.text.trim(),
                    });
                  });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Adicionar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
