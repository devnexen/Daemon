/*
===========================================================================

Daemon GPL Source Code
Copyright (C) 1999-2010 id Software LLC, a ZeniMax Media company.

This file is part of the Daemon GPL Source Code (Daemon Source Code).

Daemon Source Code is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Daemon Source Code is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Daemon Source Code.  If not, see <http://www.gnu.org/licenses/>.

In addition, the Daemon Source Code is also subject to certain additional terms.
You should have received a copy of these additional terms immediately following the
terms and conditions of the GNU General Public License which accompanied the Daemon
Source Code.  If not, please request a copy in writing from id Software at the address
below.

If you have questions concerning this license or the applicable additional terms, you
may contact in writing id Software LLC, c/o ZeniMax Media Inc., Suite 120, Rockville,
Maryland 20850 USA.

===========================================================================
*/

#include "../../engine/qcommon/q_shared.h"
#include <string>
#include <vector>
#include <list>

#ifndef SHARED_COMMAND_H_
#define SHARED_COMMAND_H_

namespace Cmd {

    typedef enum {
        NO_AUTO_REGISTER = BIT(0),
        BASE             = BIT(1),
        SYSTEM           = BIT(2),
        RENDERER         = BIT(3),
        SOUND            = BIT(4),
        GAME             = BIT(5),
        CGAME            = BIT(6),
        PROXY_FOR_OLD    = BIT(31)
    } cmdFlags_t;


    void Init();

    std::string Escape(const std::string& text, bool quote = false);
    void Tokenize(const std::string& text, std::vector<std::string>& tokens, std::vector<int>& tokenStarts);
    std::list<std::string> SplitCommands(const std::string& commands);

    class Args {
        public:
            Args();
            //Do that later, the original command line should be the concatenation of quoted args
            //Args(const std::vector<std::string>& args);
            Args(const std::string& command, bool parseCvars = false);

            int Argc() const;
            const std::string& Argv(int argNum) const;
            std::string QuotedArgs(int start = 1, int end = -1) const;
            std::string OriginalArgs(int start = 1, int end = -1) const;

            int ArgNumber(int pos);
            int ArgStart(int argNum);

            const std::vector<std::string>& GetArgs() const;

        private:
            std::vector<std::string> args;
            std::vector<int> argsStarts;
            std::string cmd;

            //TODO: move these somewhere else, once done ?
            static std::string SubstituteCvars(const std::string& text);
    };

    class CmdBase {
        public:
            virtual void Run(const Args& args) const = 0;
            virtual std::vector<std::string> Complete(int argNum, const Args& args) const;

            const std::string& GetCanonicalName() const;
            const std::string& GetDescription() const;
            cmdFlags_t GetFlags() const;

            CmdBase* next;

        protected:
            CmdBase(const std::string name, cmdFlags_t flags, const std::string description);

        private:

            std::string name;
            std::string description;
            cmdFlags_t flags;
    };
}

#endif // SHARED_COMMAND_H_
