import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:json2dart_serialization/generator.dart';
import 'package:json2dart_serialization/storage.dart';

String? entityName;

bool useJsonKey = true;

bool isCamelCase = true;
bool isStaticMethod = true;

var downloadFileName = "";

// const defaultValue = """{
//   "body": "",
//   "data": [1],
//   "input_content":["1"],
//   "list1":[{"name":"hello"}],
//   "number": [1.02],
//   "user":{"name":"abc"}
// }""";
const defaultValue = "";

enum Version { v0, v1, v2 }

Version v = Version.v0;

late TextAreaElement eResult;
late TextAreaElement eClassName;
late Element editButton;
void main() async {
  isChinese = await _isChinese();
  var dataHelper = CookieHelper();
  final jsonInput = querySelector("#json") as TextAreaElement;
  eClassName = querySelector("#class_name") as TextAreaElement;
  eResult = querySelector("#result") as TextAreaElement;
  jsonInput.value = dataHelper.loadJsonString();

  jsonInput.onInput.listen((event) {
    dataHelper.saveJsonString(jsonInput.value ?? "");
    refreshData();
  });

  InputElement entityNameEle = querySelector("#out_entity_name") as InputElement;
  entityNameEle.value = dataHelper.loadEntityName();
  entityName = entityNameEle.value ?? "";
  entityNameEle.onInput.listen((event) {
    entityName = entityNameEle.value ?? "";
    dataHelper.saveEntityName(entityName ?? "");
    refreshData();
  });

  ButtonElement formatButton = querySelector("#format") as ButtonElement;
  formatButton.onClick.listen((click) {
    String pretty;
    pretty = convertJsonString(jsonInput.value ?? "");
    try {
      pretty = formatJson(pretty);
    } on Exception {
      return;
    }
    jsonInput.value = pretty;
  });

  InputElement eJsonKey = querySelector("#use_json_key") as InputElement;
  InputElement eCamelCase = querySelector("#camelCase") as InputElement;
  InputElement eUseStatic = querySelector("#use_static") as InputElement;
  TextAreaElement result = querySelector("#result") as TextAreaElement;
  RadioButtonInputElement v0 = querySelector("#v0") as RadioButtonInputElement;
  RadioButtonInputElement v1 = querySelector("#v1") as RadioButtonInputElement;
  RadioButtonInputElement v2 = querySelector("#v2") as RadioButtonInputElement;

  void updateVersioin() {
    if (v2.checked == true) {
      v = Version.v2;
    } else if (v1.checked == true) {
      v = Version.v1;
    } else {
      v = Version.v0;
    }

    dataHelper.saveVersion(v);
  }

  void updateVersionUI() {
    if (v == Version.v2) {
      v2.checked = true;
    } else if (v == Version.v1) {
      v1.checked = true;
    } else {
      v0.checked = true;
    }
  }

  v = dataHelper.loadVersion();

  updateVersionUI();

  v0.onInput.listen((event) {
    updateVersioin();
    refreshData();
  });
  v1.onInput.listen((event) {
    updateVersioin();
    refreshData();
  });
  v2.onInput.listen((event) {
    updateVersioin();
    refreshData();
  });

  void onJsonKeyChange() {
    useJsonKey = eJsonKey.checked ?? false;
    eCamelCase.disabled = !useJsonKey;
    isCamelCase = eCamelCase.checked ?? false;
    if (!useJsonKey) isCamelCase = false;
    refreshData();
  }

  eJsonKey.checked = useJsonKey;
  eJsonKey.onInput.listen((event) {
    onJsonKeyChange();
  });

  querySelector("#check_label")?.onClick.listen((event) {
    eJsonKey.checked = !(eJsonKey.checked ?? false);
    onJsonKeyChange();
  });

  eCamelCase.checked = isCamelCase;
  eCamelCase.onInput.listen((event) {
    isCamelCase = eCamelCase.checked ?? false;
    refreshData();
  });

  querySelector("#camelCaseLabel")?.onClick.listen((event) {
    eCamelCase.checked = !(eCamelCase.checked ?? false);
    refreshData();
  });

  eUseStatic.checked = isStaticMethod;
  eUseStatic.onInput.listen((event) {
    isStaticMethod = eUseStatic.checked ?? false;
    refreshData();
  });

  querySelector("#useStaticLabel")?.onClick.listen((event) {
    eUseStatic.checked = !(eUseStatic.checked ?? false);
    refreshData();
  });

  refreshData();

  querySelector("#copy")?.onClick.listen((event) {
    result.focus();
    result.setSelectionRange(0, result.textLength ?? 0);
    document.execCommand("copy", null, "");
    result.blur();
  });

  ButtonElement saveButton = querySelector("#save") as ButtonElement;
  saveButton.onClick.listen((event) async {
    Blob blob = Blob([result.value]);
    // FileSystem _filesystem =
    //     await window.requestFileSystem(1024 * 1024, persistent: false);
    // FileEntry fileEntry = await _filesystem.root.createFile('dart_test.csv');
    // FileWriter fw = await fileEntry.createWriter();
    // fw.write(blob);
    // File file = await fileEntry.file();
    AnchorElement saveLink = document.createElementNS("http://www.w3.org/1999/xhtml", "a") as AnchorElement;
    saveLink.href = Url.createObjectUrlFromBlob(blob);
    // saveLink.type = "download";
    saveLink.download = downloadFileName;
    saveLink.click();
  });

  editButton = querySelector("#edit_class")!;
  editButton.onClick.listen((event) {
    showOrClassName();
  });

  eClassName.onInput.listen((event) {
    refreshClassNameChange(eClassName.text ?? "");
  });
}

Future<bool> _isChinese() async {
  // var lang = await findSystemLocale();
  List<MetaElement> elements = querySelectorAll("meta");

  String? lang;
  for (var e in elements) {
    var _lang = e.getAttribute("lang");
    if (_lang != null) {
      lang = _lang;
      break;
    }
  }
  if (lang?.contains("zh") == true) {
    return true;
  }

  return false;
}

bool isChinese = false;
late Generator generator;
void refreshData() async {
  TextAreaElement jsonInput = querySelector("#json") as TextAreaElement;
  var string = jsonInput.value;
  TextAreaElement result = querySelector("#result") as TextAreaElement;

  try {
    formatJson(string ?? "");
  } on Exception {
    if (isChinese) {
      result.value = "不是一个正确的json";
    } else {
      result.value = "Not JSON";
    }
    return;
  }
  String entityClassName;
  if (entityName == null || entityName == "" || entityName?.trim() == "") {
    entityClassName = "Entity";
  } else {
    entityClassName = entityName ?? "";
  }

  generator = Generator(string ?? "", entityClassName, v);
  generator.refreshAllTemplates();
  writeClassNameText(generator);
  makeCode(generator);
}

void writeClassNameText(Generator generator) {
  String names = generator.getClassNameText();
  eClassName.text = names;
}

void makeCode(Generator generator) {
  var dartCode = generator.makeDartCode();
  var dartFileName = ("${generator.fileName}.dart");
  downloadFileName = dartFileName;

  String filePrefix;
  if (isChinese) {
    filePrefix = "应该使用的文件名为:";
  } else {
    filePrefix = "your dart file name is:";
  }
  final resultName = "$filePrefix $dartFileName";
  writeToResult(resultName, dartCode);
}

void writeToResult(String resultName, String resultText) {
  // print(filePrefix);
  querySelector("#file_name")?.text = resultName;
  eResult.value = resultText;
}

String formatJson(String jsonString) {
  var map = json.decode(jsonString);
  var prettyString = JsonEncoder.withIndent("  ").convert(map);
  return prettyString;
}

void showOrClassName() {
  final currentState = !eClassName.hidden;

  eClassName.hidden = !eClassName.hidden;
  eResult.hidden = !eResult.hidden;

  editButton.text = currentState ? "name" : "result";
}

void refreshClassNameChange(String text) {
  final value = generator.makeDartCode();
  String filePrefix;
  if (isChinese) {
    filePrefix = "应该使用的文件名为:";
  } else {
    filePrefix = "your dart file name is:";
  }
  var dartFileName = ("${generator.fileName}.dart");
  downloadFileName = dartFileName;
  final resultName = "$filePrefix $dartFileName";
  writeToResult(resultName, value);
}
