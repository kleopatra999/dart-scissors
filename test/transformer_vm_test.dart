// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
library scissors.test;

import 'package:barback/barback.dart' show BarbackMode, BarbackSettings, Transformer;
import 'package:code_transformers/tests.dart' show StringFormatter, applyTransformers;
import 'package:scissors/transformer.dart' show ScissorsTransformerGroup;
import 'package:test/test.dart' show test;
import 'dart:io';

final phases =
  new ScissorsTransformerGroup.asPlugin(
      new BarbackSettings({}, BarbackMode.RELEASE))
          .phases;

void main() {
  _testPhases('leaves css based on angular2 annotations without css url alone', phases, {
    'a|foo2_unmatched_css_url.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    ''',
    'a|foo2_unmatched_css_url.dart': r'''
      import 'package:angular2/angular2.dart';

      @Component(selector = 'foo2_unmatched_css_url')
      @View(template = '<present-element></present-element>',
          styleUrls = const ['package:a/something_else.css'])
      class FooComponent {}

      @Component(selector = 'bar')
      @View(template = '<div class="used-class inexistent-class"></div>')
      class BarComponent {}
    ''',
  }, {
    'a|foo2_unmatched_css_url.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    '''
  });
  _testPhases('does basic class and element selector pruning', phases, {
    'a|foo2_html.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    ''',
    'a|foo2_html.html': r'''
      <!-- Spice this up -->
      <present-element class="used-class inexistent-class">
      </present-element>
    ''',
  }, {
    'a|foo2_html.css': r'''
      .used-class {}
      present-element {}
    '''
  });
  _testPhases('prunes css based on angular2 annotations in .dart companion', phases, {
    'a|foo2_dart.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    ''',
    'a|foo2_dart.dart': r'''
      import 'package:angular2/angular2.dart';

      @Component(selector = 'foo')
      @View(template = '<present-element></present-element>',
          styleUrls = const ['package:a/foo2_dart.css'])
      class FooComponent {}

      @Component(selector = 'bar')
      @View(template = '<div class="used-class inexistent-class"></div>',
          styleUrls = const ['package:a/foo2_dart.css'])
      class BarComponent {}
    ''',
  }, {
    'a|foo2_dart.css': r'''
      .used-class {}
      present-element {}
    '''
  });
  _testPhases('prunes css based on angular1 annotations in .dart companion', phases, {
    'a|foo1.css': r'''
      absent-element {}
      present-element {}
    ''',
    'a|foo1.dart': r'''
      import 'package:angular/angular.dart';
      @Component(
        selector = 'foo',
        template = '<present-element></present-element>',
        cssUrl = 'package:a/foo1.css')
      class FooComponent {}
    ''',
  }, {
    'a|foo1.css': r'''
      present-element {}
    '''
  });
  _testPhases('resolves local css files in angular2', phases, {
    'a|foo2_local.css': r'''
      absent-element {}
      present-element {}
    ''',
    'a|foo2_local.dart': r'''
      import 'package:angular/angular.dart';
      @View(
        template = '<present-element></present-element>',
        styleUrls = const ['foo2_local.css'])
      class FooComponent {}
    ''',
  }, {
    'a|foo2_local.css': r'''
      present-element {}
    '''
  });

  _testPhases('only prunes css which html it could resolve', phases, {
    'a|foo.css': r'.some-class {}',
    'a|bar.css': r'.some-class {}',
    'a|baz.scss.css': r'.some-class {}',
    'a|foo.html': r'<div></div>',
    'a|baz.html': r'<div></div>',
  }, {
    'a|foo.css': r'',
    'a|bar.css': r'.some-class {}',
    'a|baz.scss.css': r'',
  });

  _testPhases('supports descending and attribute selectors', phases, {
    'a|foo.css': r'''
      html body input[type="submit"] {}
      html body input[type="checkbox"] {}
    ''',
    'a|foo.html': r'''
      <input type="submit">
    ''',
  }, {
    'a|foo.css': r'''
      html body input[type="submit"] {}
    ''',
  });

  _testPhases('processes class attributes with mustaches', phases, {
    'a|foo.css': r'''
      .what_1 {}
      .what-2 {}
      .what-3 {}
      .pre1-mid-suff1 {}
      .pre1--suff1 {}
      .pre1-suff_ {}
      .pre_-suff1 {}
      .pre2-suff_ {}
      .pre_-suff2 {}
    ''',
    'a|foo.html': r'''
      <div class="what_1 pre1-{{whatever}}-suff1 pre2{{...}}
                  {{...}}suff2 what-3"></div>
    ''',
  }, {
    'a|foo.css': r'''
      .what_1 {}
      .what-3 {}
      .pre1-mid-suff1 {}
      .pre1--suff1 {}
      .pre2-suff_ {}
      .pre_-suff2 {}
    ''',
  });

  _testPhases('uses constant class names from ng-class', phases, {
    'a|foo.css': r'''
      .used-class {}
      .unused-class {}
      absent-element {}
      present-element {}
    ''',
    'a|foo.html': r'''
      <present-element ng-class="{
        'used-class': ifOnly,
        'inexistent-class': notAChance
      }">
      </present-element>
    ''',
  }, {
    'a|foo.css': r'''
      .used-class {}
      present-element {}
    '''
  });
  _testPhases('leaves weird css files alone', phases,
      {'a|weird.ess.scss.css': r"don't even try to parse me!"},
      {'a|weird.ess.scss.css': r"don't even try to parse me!"});

  final htmlBodyDiv = r'''
      html{font-family:sans-serif}
      body{font-family:sans-serif}
      div{font-family:sans-serif}
    ''';
  _testPhases('deals with synthetic html and body', phases, {
    'a|html.css': htmlBodyDiv,
    'a|html.html': r'<html></html>',
    'a|body.css': htmlBodyDiv,
    'a|body.html': r'<body></body>',
    'a|div.css': htmlBodyDiv,
    'a|div.html': r'<div></div>',
  }, {
    'a|html.css': r'''
      html{font-family:sans-serif}
      body{font-family:sans-serif}
    ''',
    'a|body.css': r'''
      body{font-family:sans-serif}
    ''',
    'a|div.css': r'''
      div{font-family:sans-serif}
    '''
  });

  _testPhases('inlines images', phases, {
    'a|foo.scss': r'''
      div {
        background-image: inline-image('icon.svg');
      }
    ''',
    'a|icon.svg': r'''
      <?xml version="1.0" encoding="utf-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        <rect x="0" y="0" height="10" width="10" style="stroke:#00ff00; fill: #ff0000"/>
      </svg>
    ''',
    'a|foo.html': r'<div></div>',
  }, {
    'a|foo.scss.css':
        'div{background-image:url(data:image/svg+xml;base64,ICAgICAgPD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KICAgICAgPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIj4KICAgICAgICA8cmVjdCB4PSIwIiB5PSIwIiBoZWlnaHQ9IjEwIiB3aWR0aD0iMTAiIHN0eWxlPSJzdHJva2U6IzAwZmYwMDsgZmlsbDogI2ZmMDAwMCIvPgogICAgICA8L3N2Zz4KICAgIA==)}\n'
        '\n'
        '/*# sourceMappingURL=foo.scss.css.map */'
  });

  if (Process.runSync('which', ['sassc']).exitCode == 0) {
    runSassTests();
  } else {
    // TODO(ochafik): Find a way to get sassc on travis (if possible,
    // without having to compile it ourselves).
    print("WARNING: Skipping Sass tests by lack of sassc in the PATH.");
  }
}

runSassTests() {
  _testPhases('runs sassc on .scss and .sass inputs', phases, {
    'a|foo.scss': '''
      .foo {
        float: left;
      }
    ''',
    'a|foo.sass': '''
.foo
  height: 100%
    '''
  }, {
    'a|foo.scss.css':
        '.foo{float:left}\n'
        '\n'
        '/*# sourceMappingURL=foo.scss.css.map */',
    'a|foo.scss.css.map':
        '{\n'
        '\t"version": 3,\n'
        '\t"file": "foo.scss.css",\n'
        '\t"sources": [\n'
        '\t\t"foo.scss"\n'
        '\t],\n'
        '\t"sourcesContent": [],\n'
        '\t"mappings": "AAAM,IAAI,AAAC,CACH,KAAK,CAAE,IAAK,CADR",\n'
        '\t"names": []\n'
        '}',
    'a|foo.sass.css':
        '.foo{height:100%}\n'
        '\n'
        '/*# sourceMappingURL=foo.sass.css.map */',
    'a|foo.sass.css.map':
        '{\n'
        '\t"version": 3,\n'
        '\t"file": "foo.sass.css",\n'
        '\t"sources": [\n'
        '\t\t"foo.sass"\n'
        '\t],\n'
        '\t"sourcesContent": [],\n'
        '\t"mappings": "AAAA,IAAI,AAAC,CACH,MAAM,CAAE,IAAK,CADT",\n'
        '\t"names": []\n'
        '}'
  });

  _testPhases('does not run sassc on .scss that are already converted', phases, {
    'a|foo.scss': '''
      .foo {
        float: left;
      }
    ''',
    'a|foo.scss.css': '/* do not modify */'
  }, {
    'a|foo.scss.css': '/* do not modify */'
  });

  _testPhases('reports sassc errors properly', phases, {
    'a|foo.scss': '''
      .foo {{
        float: left;
      }
    '''
  }, {}, [
    'error: invalid property name (a%7Cfoo.scss 1 12)'
  ]);
}

_testPhases(String testName, List<List<Transformer>> phases,
    Map<String, String> inputs, Map<String, String> results,
    [List<String> messages,
    StringFormatter formatter = StringFormatter.noTrailingWhitespace]) {
  test(testName, () async => applyTransformers(phases,
      inputs: inputs, results: results,
      messages: messages, formatter: formatter));
}
