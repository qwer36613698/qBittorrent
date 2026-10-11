// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include "base/bittorrent/addtorrentparams.h"
#include "base/path.h"
#include "base/utils/fs.h"

namespace RSS
{
    // A feed name is a single directory component, never a relative path.
    inline Path feedSavePath(const Path &basePath, const QString &name, const bool enabled)
    {
        if (!enabled || basePath.isEmpty() || (name != name.trimmed())
                || name.contains(u'\\') || !Utils::Fs::isValidName(name))
        {
            return {};
        }
        return basePath / Path(name);
    }

    inline BitTorrent::AddTorrentParams withFeedSavePath(BitTorrent::AddTorrentParams params, const Path &feedPath)
    {
        // An explicitly configured rule/destination always wins.
        if (params.savePath.isEmpty() && !feedPath.isEmpty())
        {
            params.savePath = feedPath;
            params.useAutoTMM = false;
        }
        return params;
    }
}
