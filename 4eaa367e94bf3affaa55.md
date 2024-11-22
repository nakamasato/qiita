---
title: [Java] FastDateFormatでParseする
tags: Java FastDateFormat
author: nakamasato
slide: false
---
# FastDateFormatとは

https://commons.apache.org/proper/commons-lang/apidocs/org/apache/commons/lang3/time/FastDateFormat.html

> FastDateFormat is a fast and thread-safe version of SimpleDateFormat.

`FastDateFormat`は、 `SimpleDateFormat`の早くてスレッドセーフ版。

> This class can be used as a direct replacement to * {@code SimpleDateFormat} in most formatting and parsing situations. * This class is especially useful in multi-threaded server environments. * {@code SimpleDateFormat} is not thread-safe in any JDK version, * nor will it be as Sun have closed the bug/RFE.

「ほとんどのケースのformatとparseにおいて、`SimpleDateFormat`の代替となる」と書かれている。

# 基本的な使い方

Apache Commons Langをhttps://mvnrepository.com/artifact/org.apache.commons/commons-lang3/3.12.0 から追加する (今回は3.12.0を使用)

```java
import java.text.ParseException;
import java.util.Date;

import org.apache.commons.lang3.time.FastDateFormat;

public class FastDateFormatBasic {

  public static void main(String[] args) {
    FastDateFormat tsDatetimeFormat = FastDateFormat.getInstance("yyyy/MM/dd HH:mm:ss z");
    try {
      Date parsedDate = tsDatetimeFormat.parse("2021/08/15 00:00:00 UTC");
      System.out.println(parsedDate);
    } catch (ParseException e1) {
    }
  }
}
```

実行結果: 

```
Sun Aug 15 09:00:00 JST 2021
```

(実行環境のTimezoneで表示される。)

# 内部実装

![fast-date-format.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/7059/02d24c95-6881-8fec-bf6c-8fb0f649c8bf.png)

1. `FastDateFormat`のInstanceは以下のいずれかの方法で取得する。 今回は、1つ目の`getInstance`をとりあげて見る
    1. `getInstance(String, TimeZone, Locale)`
    1. `getDateInstance(int, TimeZone, Locale)`
    1. `getTimeInstance(int, TimeZone, Locale)`
    1. `getDateTimeInstance(int, int, TimeZone, Locale)`

1. `getInstance(String pattern, TimeZone timezone, Locale locale)`は `FormatCache`のgetInstanceをよんでいる。

    ```java
    public static FastDateFormat getInstance(final String pattern) {
        return cache.getInstance(pattern, null, null);
    }
    ```

1. cacheは、`FormatCache`というClassで、 `FastDateFormat`のCacheを確保している

    ```java
    private static final FormatCache<FastDateFormat> cache = new FormatCache<FastDateFormat>() {
        @Override
        protected FastDateFormat createInstance(final String pattern, final TimeZone timeZone, final Locale locale) {
            return new FastDateFormat(pattern, timeZone, locale);
        }
    };
    ```

    cacheのキーには、 `pattern`,`timezone`, `locale`の3つが使われておりこれらが同じであれば同じInstanceが返される。 ([FormatCache.getInstance(final String pattern, TimeZone timeZone, Locale locale)](https://github.com/apache/commons-lang/blob/7c658527094083b2037d362916adf8eb2493ea65/src/main/java/org/apache/commons/lang3/time/FormatCache.java#L70-L88))

1. `FastDateFormat`のConstructorでは、 `FastDateParser`と`FastDatePrinter`を初期化する

    ```java
    protected FastDateFormat(final String pattern, final TimeZone timeZone, final Locale locale, final Date centuryStart) {
        printer = new FastDatePrinter(pattern, timeZone, locale);
        parser = new FastDateParser(pattern, timeZone, locale, centuryStart);
    }
    ```

    1. `FastDateParser`は、 `FastDateFormat.parse(final String source)`内でそのまま `parser.parse(source)`が呼ばれている。パースのロジックはすべて`FastDateParser`の中にある
    1. `FastDatePrinter`は、 `pattern`で指定したフォーマットに整形して表示するClassで、 `FastDateFormat.format()`は `printer.format`を読んでいて表示部分のロジックは、 `FastDatePrinter` にある。

1. `FastDateParser.parse()`の中身
    1. まずParsePositionを0として、 `parse(final String source, final ParsePosition pos)` を呼び返り値の`Date`を返す。
    1. `parse(final String source, final ParsePosition pos)`では、 `Calendar`インスタンスをセットし、 `parse(source, pos, cal)`を呼び結果のBooleanがTrueの場合は、 `cal.getTime()`を返し、それ以外の場合は、 nullを返す。

        ```java
        public Date parse(final String source, final ParsePosition pos) {
            // timing tests indicate getting new instance is 19% faster than cloning
            final Calendar cal = Calendar.getInstance(timeZone, locale);
            cal.clear();

            return parse(source, pos, cal) ? cal.getTime() : null;
        }
        ```
    1. `parse(source, pos, cal)` では、 イテレータの`patterns`に対するループで、 patternに対するStrategyを取得し、対応するStrategyでParseし、パースが失敗した時点でfalseを返す。すべてのParseが成功したときにtrueを返す。

        ```java
            public boolean parse(final String source, final ParsePosition pos, final Calendar calendar) {
                final ListIterator<StrategyAndWidth> lt = patterns.listIterator();
                while (lt.hasNext()) {
                    final StrategyAndWidth strategyAndWidth = lt.next();
                    final int maxWidth = strategyAndWidth.getMaxWidth(lt);
                    if (!strategyAndWidth.strategy.parse(this, calendar, source, pos, maxWidth)) {
                        return false;
                    }
                }
                return true;
            }
        ```

        1. `patterns` は constructorで呼ばれている`init()`関数でセットされている。中では、 `StrategyParser`で`pattern`　(e.g. `yyyy/MM/dd HH:mm:ss z`) の文字一つずつに対してどのStrategyかとwidthをセットにした `StrategyAndWidth`を決定してセットしている
            1. `strategyAndWidth.strategy.parse`では各Strategyの`parse`関数の中で、 `setCalendar`関数が呼ばれて、渡されているcalendarが更新される
    1. `cal.getTime()` は、以下のようにミリセカンドからDateを初期化して返している

        ```java
        public final Date getTime() {
                return new Date(getTimeInMillis());
        }
        ```

# ハマったポイント

以下のように、Stringからタイムゾーンを取得しようとして、 `FastDateFormat`を使ってみようとしたが、`SimpleDateFormat`ではできるが、`FastDateFormat`ではできなかった。Thread-safeにするために、calendarを`FastDateFormat`に持たせないようにした影響と思われれる。

例.

- pattern: `yyyy/MM/dd HH:mm:ss z`
- parseする対象: 様々なTimeZoneを持った文字列
    - `2021/07/10 00:00:00 UTC`
    - `2021/07/10 00:00:00 PDT`
- やりたいこと: 各インプットで指定されたTimeZoneを取得

以下のように、


```java
package com.example.time;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

import org.apache.commons.lang3.time.FastDateFormat;

public class FastDateFormatCheck {

    public static void main(String[] args) {
        FastDateFormat fastDateFormat = FastDateFormat.getInstance("yyyy/MM/dd HH:mm:ss z");
        DateFormat dateFormat = new SimpleDateFormat("yyyy/MM/dd HH:mm:ss z");

        String[] timeStamps = new String[] {
                "2021/07/10 00:00:00 UTC",
                "2021/07/10 00:00:00 PDT",
        };
        for (String timeStamp : timeStamps) {
            try {
                Date fastDate = fastDateFormat.parse(timeStamp);
                Date normalDate = dateFormat.parse(timeStamp);
                System.out.println("[FastDateFormat]\tsource: " + timeStamp + "\tparsed: " + fastDate + "\tgetTimeZone: " + fastDateFormat.getTimeZone().getID());
                System.out.println("[SimpleDateFormat]\tsource: " + timeStamp + "\tparsed: " + normalDate + "\tgetTimeZone: " + dateFormat.getTimeZone().getID());
            } catch (ParseException e1) {
            }
            System.out.println("------------------------------------");
        }
    }
}
```

結果: 

```
[FastDateFormat]        source: 2021/07/10 00:00:00 UTC parsed: Sat Jul 10 09:00:00 JST 2021    getTimeZone: Asia/Tokyo
[SimpleDateFormat]      source: 2021/07/10 00:00:00 UTC parsed: Sat Jul 10 09:00:00 JST 2021    getTimeZone: UTC
------------------------------------
[FastDateFormat]        source: 2021/07/10 00:00:00 PDT parsed: Sat Jul 10 16:00:00 JST 2021    getTimeZone: Asia/Tokyo
[SimpleDateFormat]      source: 2021/07/10 00:00:00 PDT parsed: Sat Jul 10 16:00:00 JST 2021    getTimeZone: America/Los_Angeles
------------------------------------
```

内部実装からも分かる通り、`FastDateFormat`ではTimeZoneの情報はCalendarに更新されるが、Calendarオブジェクトは `FastDateParser`の`parse`関数内のローカル変数のため、`FastDateFormat`から取得することはできない。また、`parse`の結果も millisecondsからDateオブジェクトを初期化して返しているので、もともと文字列内にあった`TimeZone`情報は含まれていない。
`SimpleDateFormat`の場合は (内部ロジックを詳しく見ていないが) `Calendar`インスタンスが`SimpleDateFormat`に保持されていてparse時に更新されていて、`getTimeZone()`では、 `return calendar.getTimeZone();`と返しているためにTimeZoneをパースした文字列から取得できている。

# まとめ

- `FastDateFormat`は、`SimpleDateFormat`の高速版且つThread-safe版として代替に使われる
- `FastDateFormat`は、`getInstance`でのみインスタンスを取得できる
- `FastDateFormat`内には、 `FormatCache`に `FastDateFormat`をキャッシュしていて`getInstance`で `pattern`, `timezone`, `locale`をキーにCacheを作成または既存のインスタンスを返す
- `FastDateFormat`には、`FastDatePrinter`と`FastDateParser`があり、それぞれにFormatとParseのロジックが実装されている
- `FastDateParser`の`parse`では、 `Calendar`を取得し、`pattern`に対して一文字ずつ`ParseStrategy`と`width`を決め、対応するstrategyのparseの中で、`calendar`を更新し、最終的に、`calendar.getTime()`で`Date`オブジェクトを返す
- calendarの返しかたから、 `FastDateFormat`では、 parseしたStringの中にあったTimeZoneがどこだったかの情報は取得できない。 


# 参考

- [Why is Java's SimpleDateFormat not thread-safe? [duplicate]](https://stackoverflow.com/questions/6840803/why-is-javas-simpledateformat-not-thread-safe)
- https://www.joda.org/joda-time/
- https://commons.apache.org/proper/commons-lang/apidocs/org/apache/commons/lang3/time/FastDateFormat.html
- https://github.com/apache/commons-lang/blob/master/src/main/java/org/apache/commons/lang3/time/FastDateFormat.java

