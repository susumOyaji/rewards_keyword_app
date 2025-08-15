import 'dart:convert';
import 'dart:html' as html;
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
  Map<String, List<String>> _displayKeywords = {};

  // UI states
  final TextEditingController _textController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  String? _selectedKeyword;
  String _rawJsonResponse = ''; // Added to hold the raw JSON response

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() { _isLoading = true; _error = null; });

    // 1. Fetch user keywords from Cloudflare KV
    try {
      final response = await http.get(Uri.parse('https://rewards-keyword-worker.sumitomo0210.workers.dev/get'));
      if (response.statusCode == 200) {
        // Pretty print JSON
        const jsonEncoder = JsonEncoder.withIndent('  ');
        final decodedMap = jsonDecode(response.body);
        setState(() {
          _rawJsonResponse = jsonEncoder.convert(decodedMap);
        });
        _userKeywords = (decodedMap as Map<String, dynamic>).map((key, value) => MapEntry(key, List<String>.from(value)));
      } else if (response.statusCode == 404) {
        setState(() {
          _rawJsonResponse = 'No data found on server (404).';
        });
        // 404 (Not Found) is okay, just means no data yet. Other errors are problems.
      } else {
        setState(() {
          _rawJsonResponse = 'Error fetching data: ${response.statusCode}\n${response.body}';
        });
        _error = 'Failed to load saved keywords: ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        _rawJsonResponse = 'Error connecting to keyword server: $e';
      });
      _error = 'Error connecting to keyword server: $e';
    }

    // 2. Fetch base keywords from web
    try {
      final response = await http.get(Uri.parse('https://yoshizo.hatenablog.com/entry/microsoft-rewards-search-keyword-list/#movie'));
      if (response.statusCode == 200) {
        final document = parse(response.body);
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
              String keywordText = li.text.trim().replaceAll(RegExp(r'\(.*?\)'), '').trim();
              keywordText = keywordText.replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
              keywordText = keywordText.replaceAll(RegExp(r'^-+\s*'), '').trim();
              if (keywordText.isNotEmpty) keywords.add(keywordText);
            }
          }
          if (keywords.isNotEmpty) fetched[categoryName] = keywords;
        }
        _fetchedKeywords = fetched;
      } else {
         _error = '${_error ?? ''}\nFailed to load web keywords: ${response.statusCode}';
      }
    } catch (e) {
      _error = '${_error ?? ''}\nError fetching web keywords: $e';
    }

    // 3. Merge data and update UI
    _mergeKeywordsAndRefreshUi();
  }

  void _mergeKeywordsAndRefreshUi() {
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

    setState(() {
      _displayKeywords = merged;
      if (_selectedCategory == null && _displayKeywords.isNotEmpty) {
        _selectedCategory = _displayKeywords.keys.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveKeywordsToKV() async {
    // This function now saves the USER-ADDED keywords to KV.
    final url = Uri.parse('https://rewards-keyword-worker.sumitomo0210.workers.dev/save');
    final headers = {'Content-Type': 'application/json'};
    // We only save the keywords that are in _userKeywords, not the merged list.
    final body = jsonEncode(_userKeywords);

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keywords saved successfully!')), 
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save keywords. Server responded with ${response.statusCode}')),
        );
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
      final userCategoryKeywords = _userKeywords.putIfAbsent(_selectedCategory!, () => []);
      if (!userCategoryKeywords.contains(text)) {
        userCategoryKeywords.add(text);
      }
      _textController.clear();
      _saveKeywordsToKV(); // Changed to save to KV
      _mergeKeywordsAndRefreshUi();
    }
  }

  void _removeKeyword(String category, String keyword) {
    if (_userKeywords.containsKey(category)) {
      _userKeywords[category]!.remove(keyword);
      if (_userKeywords[category]!.isEmpty) {
        _userKeywords.remove(category);
      }
    }
    _saveKeywordsToKV(); // Changed to save to KV
    _mergeKeywordsAndRefreshUi();
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () => launchUrl(Uri.parse('https://yoshizo.hatenablog.com/entry/microsoft-rewards-search-keyword-list/#movie')),
              child: const Text('出典: yoshizo.hatenablog.com', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Add a keyword'),
                  ),
                ),
                if (_displayKeywords.isNotEmpty)
                  DropdownButton<String>(
                    value: _selectedCategory,
                    hint: const Text('Category'),
                    items: _displayKeywords.keys.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addKeyword),
                // The "export" button now saves to KV
                IconButton(icon: const Icon(Icons.save), onPressed: _saveKeywordsToKV, tooltip: 'Save keywords to Cloud'),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                      : ListView(children: _buildCategoryWidgets()),
            ),
          ),
          // Added ExpansionTile to show raw JSON
          ExpansionTile(
            title: const Text('Raw JSON Data from Cloudflare'),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: Colors.blueGrey[50],
                child: SelectableText(_rawJsonResponse),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryWidgets() {
    return _displayKeywords.entries.map((entry) {
      final category = entry.key;
      final keywords = entry.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 5.0, top: 10.0),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFCCCCCC), width: 1.0))),
            child: Text(category, style: const TextStyle(color: Color(0xFF555555), fontSize: 18.0, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 10.0, bottom: 10.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: keywords.map((keyword) {
                final isUserKeyword = _userKeywords[category]?.contains(keyword) ?? false;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: keyword,
                      groupValue: _selectedKeyword,
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() {
                            _selectedKeyword = value;
                          });
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to clipboard')),
                          );
                        }
                      },
                    ),
                    Flexible(child: Text(keyword)),
                    if (isUserKeyword)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => _removeKeyword(category, keyword),
                        tooltip: 'Remove keyword',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );
    }).toList();
  }
}
