// SPDX-License-Identifier: GPL-2.0-or-later
#include <QObject>
#include <QTest>

#include "base/global.h"
#include "base/rss/rss_downloadpath.h"

class TestRSSDownloadPath final : public QObject
{
    Q_OBJECT

private slots:
    void namedFeed()
    {
        const Path base {u"F:/Torrent 下載"_s};
        QCOMPARE(RSS::feedSavePath(base, u"動畫"_s, true), base / Path(u"動畫"_s));
        QVERIFY(RSS::feedSavePath(base, u"動畫"_s, false).isEmpty());
        QVERIFY(RSS::feedSavePath({}, u"動畫"_s, true).isEmpty());
        const Path changedBase {u"D:/Downloads"_s};
        QCOMPARE(RSS::feedSavePath(changedBase, u"New name"_s, true), changedBase / Path(u"New name"_s));
    }

    void unsafeNames()
    {
        const Path base {u"F:/Downloads"_s};
        for (const auto &name : {u""_s, u"."_s, u".."_s, u"../other"_s, u"a/b"_s, u"a\\b"_s, u" trailing "_s})
            QVERIFY2(RSS::feedSavePath(base, name, true).isEmpty(), qPrintable(name));
#ifdef Q_OS_WIN
        for (const auto &name : {u"CON"_s, u"NUL.txt"_s, u"LPT1"_s, u"COM1"_s, u"F:/escape"_s, u"bad?name"_s, u"name."_s})
            QVERIFY2(RSS::feedSavePath(base, name, true).isEmpty(), qPrintable(name));
#endif
    }

    void destinationPrecedence()
    {
        const Path feedPath {u"F:/Downloads/動畫"_s};
        BitTorrent::AddTorrentParams params;
        params.category = u"TV"_s;
        params.useAutoTMM = true;
        auto derived = RSS::withFeedSavePath(params, feedPath);
        QCOMPARE(derived.savePath, feedPath);
        QCOMPARE(derived.useAutoTMM, std::optional<bool>(false));
        QCOMPARE(derived.category, params.category);
        params.savePath = Path(u"D:/Explicit"_s);
        QCOMPARE(RSS::withFeedSavePath(params, feedPath), params);
        QCOMPARE(RSS::withFeedSavePath(params, {}), params);
    }
};

QTEST_APPLESS_MAIN(TestRSSDownloadPath)
#include "testrssdownloadpath.moc"
