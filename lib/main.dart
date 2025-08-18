import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Microsoft Rewards Keywords',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const KeywordListScreen(),
    );
  }
}

class KeywordListScreen extends StatefulWidget {
  const KeywordListScreen({super.key});

  @override
  State<KeywordListScreen> createState() => _KeywordListScreenState();
}

class _KeywordListScreenState extends State<KeywordListScreen> {
  // Data states
  Map<String, List<String>> _fetchedKeywords = {};
  Map<String, List<String>> _userKeywords = {};

  // UI states
  final TextEditingController _textController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  String? _selectedKeyword;
  String _rawJsonResponse = '';

  // Getter for merged keywords
  Map<String, List<String>> get _displayKeywords {
    final merged = <String, List<String>>{};
    _fetchedKeywords.forEach((category, keywords) {
      merged[category] = List.from(keywords);
    });

    _userKeywords.forEach((category, keywords) {
      if (merged.containsKey(category)) {
        final existingKeywords = merged[category]!;
        for (var keyword in keywords) {
          if (!existingKeywords.contains(keyword)) {
            existingKeywords.add(keyword);
          }
        }
      } else {
        merged[category] = List.from(keywords);
      }
    });
    return merged;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _fetchUserKeywords();
      await _fetchAndParseWebKeywords();

      if (_selectedCategory == null && _displayKeywords.isNotEmpty) {
        _selectedCategory = _displayKeywords.keys.first;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserKeywords() async {
    try {
      final response = await http.get(Uri.parse('https://rewards-keyword-worker.sumitomo0210.workers.dev/get'));
      if (response.statusCode == 200) {
        const jsonEncoder = JsonEncoder.withIndent('  ');
        final decodedMap = jsonDecode(response.body);
        _rawJsonResponse = jsonEncoder.convert(decodedMap);
        _userKeywords = (decodedMap as Map<String, dynamic>).map((key, value) => MapEntry(key, List<String>.from(value)));
      } else if (response.statusCode == 404) {
        _rawJsonResponse = 'No data found on server (404).';
      } else {
        _rawJsonResponse = 'Error fetching data: ${response.statusCode}\n${response.body}';
        throw 'Failed to load saved keywords: ${response.statusCode}';
      }
    } catch (e) {
      _rawJsonResponse = 'Error connecting to keyword server: $e';
      throw 'Error connecting to keyword server: $e';
    }
  }

  Future<void> _fetchAndParseWebKeywords() async {
    try {
      final response = await http.get(Uri.parse('https://yoshizo.hatenablog.com/entry/microsoft-rewards-search-keyword-list/'));
      if (response.statusCode == 200) {
        _fetchedKeywords = _parseKeywordsFromHtml(response.body);
      } else {
        throw 'Failed to load web keywords: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error fetching web keywords: $e';
    }
  }

  Map<String, List<String>> _parseKeywordsFromHtml(String htmlBody) {
    final document = parse(htmlBody);
    final fetched = <String, List<String>>{};
    final h3Elements = document.querySelectorAll('h3');

    for (var h3 in h3Elements) {
      final categoryName = h3.text.trim();
      final keywords = <String>[];
      dom.Element? currentElement = h3.nextElementSibling;
      dom.Element? foundUl;

      while (currentElement != null) {
        if (currentElement.localName == 'ul') {
          foundUl = currentElement;
          break;
        }
        if (currentElement.localName == 'h3') break;
        final ulInDescendants = currentElement.querySelector('ul');
        if (ulInDescendants != null) {
          foundUl = ulInDescendants;
          break;
        }
        currentElement = currentElement.nextElementSibling;
      }

      if (foundUl != null) {
        final liElements = foundUl.querySelectorAll('li');
        for (var li in liElements) {
          // テキストを整形:
          // - "(...)" のような括弧書きを削除
          // - "1. " のような行頭の数字付きリストマーカーを削除
          // - "--- " のような行頭のハイフンマーカーを削除
          final keywordText = li.text
              .replaceAll(RegExp(r'\(.*?\)'), '')
              .replaceAll(RegExp(r'^\d+\.\s*'), '')
              .replaceAll(RegExp(r'^-+\s*'), '')
              .trim();

          if (keywordText.isNotEmpty) {
            keywords.add(keywordText);
          }
        }
      }
      if (keywords.isNotEmpty) fetched[categoryName] = keywords;
    }
    return fetched;
  }

  Future<void> _saveKeywordsToKV() async {
    final url = Uri.parse('https://rewards-keyword-worker.sumitomo0210.workers.dev/save');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(_userKeywords);

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keywords saved successfully!')),
        );
      } else {
        throw 'Server responded with ${response.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving keywords: $e')),
      );
    }
  }

  void _addKeyword() {
    final String text = _textController.text.trim();
    if (text.isNotEmpty && _selectedCategory != null) {
      setState(() {
        final userCategoryKeywords = _userKeywords.putIfAbsent(_selectedCategory!, () => []);
        if (!userCategoryKeywords.contains(text)) {
          userCategoryKeywords.add(text);
        }
        _textController.clear();
      });
    }
  }

  void _removeKeyword(String category, String keyword) {
    setState(() {
      if (_userKeywords.containsKey(category)) {
        _userKeywords[category]!.remove(keyword);
        if (_userKeywords[category]!.isEmpty) {
          _userKeywords.remove(category);
        }
      }
      // If the selected category was just removed (and it was a user-only category), reset the selection.
      if (!_displayKeywords.keys.contains(_selectedCategory)) {
        _selectedCategory = _displayKeywords.keys.isNotEmpty ? _displayKeywords.keys.first : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Microsoft Rewards Keywords'),
      ),
      body: Column(
        children: [
          _buildSourceLink(),
          _buildControlPanel(),
          Expanded(
            child: _buildBodyContent(),
          ),
          _buildRawJsonDisplay(),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)));
    }
    return _buildKeywordList();
  }

  Widget _buildSourceLink() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => launchUrl(Uri.parse('https://yoshizo.hatenablog.com/entry/microsoft-rewards-search-keyword-list/')),
        child: const Text('Source: yoshizo.hatenablog.com', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
      ),
    );
  }

  Widget _buildControlPanel() {
    final availableCategories = _displayKeywords.keys.toList();
    final isCategorySelected = availableCategories.contains(_selectedCategory);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (availableCategories.isNotEmpty)
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: isCategorySelected ? _selectedCategory : null,
                  hint: const Text('Category'),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: availableCategories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Add a keyword',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addKeyword(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add), onPressed: _addKeyword, tooltip: 'Add keyword'),
            IconButton(icon: const Icon(Icons.save), onPressed: _saveKeywordsToKV, tooltip: 'Save keywords to Cloud'),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      children: _displayKeywords.entries.map((entry) {
        final category = entry.key;
        final keywords = entry.value;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
          child: ExpansionTile(
            title: Text(category, style: const TextStyle(color: Color(0xFF555555), fontSize: 18.0, fontWeight: FontWeight.bold)),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20.0, top: 10.0, bottom: 10.0, right: 20.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: keywords.map((keyword) => _buildKeywordItem(category, keyword)).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeywordItem(String category, String keyword) {
    final isUserKeyword = _userKeywords[category]?.contains(keyword) ?? false;
    return InputChip(
      label: Text(keyword),
      selected: _selectedKeyword == keyword,
      pressElevation: 2.0,
      selectedColor: Colors.blue.withAlpha(60),
      onPressed: () {
        setState(() {
          _selectedKeyword = keyword;
        });
        Clipboard.setData(ClipboardData(text: keyword));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
        );
      },
      onDeleted: isUserKeyword ? () => _removeKeyword(category, keyword) : null,
    );
  }

  Widget _buildRawJsonDisplay() {
    return ExpansionTile(
      title: const Text('Raw JSON Data from Cloudflare'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: Colors.blueGrey[50],
          child: SelectableText(_rawJsonResponse),
        ),
      ],
    );
  }
}
