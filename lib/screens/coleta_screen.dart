import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Estado
  String? unidadeProdutivaSelecionada;
  String? unidadeProdutivaId;
  String origemProducao = "Própria";
  bool _salvando = false;

  List<Map<String, dynamic>> especiesRegistradas = [];
  List<Map<String, dynamic>> sugestoesUnidades = [];

  // Debounce para busca
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dataController.text = DateFormat('dd/MM/yyyy').format(now);
    _horaController.text = DateFormat('HH:mm').format(now);
    _localController.text = widget.entreposto;
  }

  // ========= Helpers =========

  String _buildUP({
    required String nome,
    required String barco,
    required String tipo,
    required String categoria,
    required String comunidade,
  }) => "$nome - $barco - $tipo - $categoria - $comunidade";

  double _toDouble(String v) {
    final s = v.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  void _showErrorSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ========= Busca UP (indexada) =========
  Future<void> _buscarUnidadesProdutivas(String termo) async {
    if (termo.length < 3) {
      setState(() => sugestoesUnidades = []);
      return;
    }
    final termoLower = termo.toLowerCase();
    try {
      final query = await _firestore
          .collection('unidades_produtivas')
          .where('unidade_produtiva_busca', isGreaterThanOrEqualTo: termoLower)
          .where(
            'unidade_produtiva_busca',
            isLessThan:
                '$termoLower'
                'z',
          )
          .limit(20)
          .get();

      final resultados = query.docs
          .map((d) => {'id': d.id, ...d.data()})
          .cast<Map<String, dynamic>>()
          .toList();

      setState(() => sugestoesUnidades = resultados);
    } catch (e) {
      debugPrint('Erro na busca de UP: $e');
      _showErrorSnack('Falha ao buscar unidades produtivas.');
    }
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

  // ========= Versionamento brando =========
  Future<void> _snapshotVersaoAnterior(
    String docId,
    Map<String, dynamic> dados,
  ) async {
    try {
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
    } catch (e) {
      debugPrint('Erro ao salvar snapshot: $e');
      _showErrorSnack('Não foi possível salvar o histórico da unidade.');
    }
  }

  // ========= Criar/Atualizar UP =========
  Future<void> _verificarOuAtualizarUnidadeProdutiva() async {
    final nome = _pescadorController.text.trim();
    final barco = _embarcacaoController.text.trim();
    final tipo = _tipoEmbarcacaoController.text.trim();
    final categoria = _categoriaEmbarcacaoController.text.trim();
    final comunidade = _comunidadeController.text.trim();

    final upConcat = _buildUP(
      nome: nome,
      barco: barco,
      tipo: tipo,
      categoria: categoria,
      comunidade: comunidade,
    );
    final upConcatBusca = upConcat.toLowerCase();

    try {
      // Nova UP
      if (unidadeProdutivaId == null) {
        final created = await _firestore.collection('unidades_produtivas').add({
          'unidade_produtiva': upConcat,
          'unidade_produtiva_busca': upConcatBusca,
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

      // UP existente
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
          'unidade_produtiva_busca': upConcatBusca,
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
          'unidade_produtiva': upConcat,
          'unidade_produtiva_busca': upConcatBusca,
          'versao': versaoNova,
          'atualizado_em': DateTime.now().toIso8601String(),
        });
      }

      unidadeProdutivaSelecionada = upConcat;
    } catch (e) {
      debugPrint('Erro ao verificar/atualizar UP: $e');
      _showErrorSnack('Falha ao atualizar/criar a unidade produtiva.');
    }
  }

  // ========= Salvar desembarque =========
  Future<void> _salvarDesembarque() async {
    if (especiesRegistradas.isEmpty) {
      _showErrorSnack('Adicione ao menos uma espécie.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await _verificarOuAtualizarUnidadeProdutiva();

      final novoDesembarque = {
        'data': _dataController.text, // exibição
        'hora': _horaController.text, // exibição
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
        // Técnico para filtros/ordenação:
        'timestamp': FieldValue.serverTimestamp(),
        'especies': especiesRegistradas,
      };

      await _firestore.collection('desembarques').add(novoDesembarque);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Desembarque salvo com sucesso!')),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      debugPrint('Erro ao salvar desembarque: $e');
      _showErrorSnack('Falha ao salvar desembarque. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ========= UI =========
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
              onChanged: (txt) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _buscarUnidadesProdutivas(txt);
                });
              },
            ),
            if (sugestoesUnidades.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: azul),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sugestoesUnidades.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (ctx, i) {
                    final u = sugestoesUnidades[i];
                    return ListTile(
                      title: Text(
                        u['unidade_produtiva'],
                        style: TextStyle(color: azul),
                      ),
                      onTap: () => _selecionarUnidade(u),
                    );
                  },
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

            const Divider(height: 24, color: Colors.black26),

            // Lista de espécies registradas
            ...especiesRegistradas.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    '${e['especie']} - ${e['quantidade']} ${e['unidade']}',
                    style: TextStyle(color: azul, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Pesqueiro: ${e['pesqueiro']} | ${e['beneficiamento'] ?? 'Bruto'} | R\$${e['preco_unidade']}/un',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        tooltip: 'Editar espécie',
                        onPressed: () => _mostrarDialogoAdicionarEspecie(
                          context,
                          especieExistente: e,
                          index: i,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remover espécie',
                        onPressed: () =>
                            setState(() => especiesRegistradas.removeAt(i)),
                      ),
                    ],
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

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarDesembarque,
                style: ElevatedButton.styleFrom(backgroundColor: azul),
                child: _salvando
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Text(
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: azul),
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
    try {
      final snap = await _firestore.collection(colecao).get();
      return snap.docs
          .map((d) => d['nome'].toString())
          .where((n) => n.toLowerCase().contains(termo.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar sugestões de $colecao: $e');
      _showErrorSnack('Falha ao buscar sugestões.');
      return [];
    }
  }

  /// Garante que o item existe na coleção, criando se não existir.
  Future<void> _garantirRegistroColecao(String colecao, String nome) async {
    final clean = nome.trim();
    if (clean.isEmpty) return;
    try {
      final query = await _firestore
          .collection(colecao)
          .where('nome', isEqualTo: clean)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        await _firestore.collection(colecao).add({
          'nome': clean,
          'ativo': true,
          'criado_em': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Erro ao garantir registro em $colecao: $e');
      _showErrorSnack('Falha ao registrar item em $colecao.');
    }
  }

  // ======================================
  // DIALOGO PARA ADICIONAR/EDITAR ESPÉCIE
  // ======================================
  Future<void> _mostrarDialogoAdicionarEspecie(
    BuildContext context, {
    Map<String, dynamic>? especieExistente,
    int? index,
  }) async {
    const azul = Color(0xFF00294D);
    final especieCtrl = TextEditingController(
      text: especieExistente?['especie'] ?? '',
    );
    final qtdCtrl = TextEditingController(
      text: especieExistente?['quantidade']?.toString() ?? '',
    );
    final precoCtrl = TextEditingController(
      text: especieExistente?['preco_unidade']?.toString() ?? '',
    );
    final arteCtrl = TextEditingController(
      text: especieExistente?['arte_pesca'] ?? '',
    );
    final pesqueiroCtrl = TextEditingController(
      text: especieExistente?['pesqueiro'] ?? '',
    );
    String unidade = especieExistente?['unidade'] ?? 'Kg';
    String beneficiamento = especieExistente?['beneficiamento'] ?? 'Bruto';

    List<String> sugestoesEspecie = [];
    List<String> sugestoesArte = [];
    List<String> sugestoesPesqueiro = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text(index == null ? 'Adicionar Espécie' : 'Editar Espécie'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Espécie
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
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: azul),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sugestoesEspecie.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.black12),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(sugestoesEspecie[i]),
                          onTap: () {
                            especieCtrl.text = sugestoesEspecie[i];
                            setStateDialog(() => sugestoesEspecie.clear());
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Quantidade
                  _buildTextField(
                    'Quantidade',
                    qtdCtrl,
                    azul,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Unidade
                  DropdownButtonFormField<String>(
                    value: unidade,
                    items: ['Kg', 'Dúzia', 'Caixa']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => unidade = v!),
                    decoration: const InputDecoration(
                      labelText: 'Unidade de medida',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Preço
                  _buildTextField(
                    'Preço por unidade (R\$)',
                    precoCtrl,
                    azul,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Beneficiamento
                  DropdownButtonFormField<String>(
                    value: beneficiamento,
                    items: ['Bruto', 'Limpo']
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => beneficiamento = v!),
                    decoration: const InputDecoration(
                      labelText: 'Beneficiamento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Arte de pesca
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
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: azul),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sugestoesArte.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.black12),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(sugestoesArte[i]),
                          onTap: () {
                            arteCtrl.text = sugestoesArte[i];
                            setStateDialog(() => sugestoesArte.clear());
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Pesqueiro
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
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: azul),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sugestoesPesqueiro.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.black12),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(sugestoesPesqueiro[i]),
                          onTap: () {
                            pesqueiroCtrl.text = sugestoesPesqueiro[i];
                            setStateDialog(() => sugestoesPesqueiro.clear());
                          },
                        ),
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
                  await _garantirRegistroColecao('especies', especieCtrl.text);
                  await _garantirRegistroColecao('artes_pesca', arteCtrl.text);
                  await _garantirRegistroColecao(
                    'pesqueiros',
                    pesqueiroCtrl.text,
                  );

                  final especieData = {
                    'especie': especieCtrl.text.trim(),
                    'quantidade': _toDouble(qtdCtrl.text),
                    'unidade': unidade,
                    'preco_unidade': _toDouble(precoCtrl.text),
                    'arte_pesca': arteCtrl.text.trim(),
                    'pesqueiro': pesqueiroCtrl.text.trim(),
                    'beneficiamento': beneficiamento,
                  };

                  setState(() {
                    if (index != null) {
                      especiesRegistradas[index] = especieData;
                    } else {
                      especiesRegistradas.add(especieData);
                    }
                  });

                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Salvar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _dataController.dispose();
    _horaController.dispose();
    _localController.dispose();
    _buscaUnidadeController.dispose();
    _pescadorController.dispose();
    _embarcacaoController.dispose();
    _tipoEmbarcacaoController.dispose();
    _categoriaEmbarcacaoController.dispose();
    _comunidadeController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
