# Derived from a SpiNNaker Project support script
# https://github.com/SpiNNakerManchester

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>

"""Set stdout and sterr streams to use blocking I/O
"""

import fcntl
from os import O_NONBLOCK as NONBLOCK
from sys import stdout, stderr


def set_blocking(stream):
    """Clear the non-blocking-IO bitflag
    """
    flags = fcntl.fcntl(stream, fcntl.F_GETFL) & (~NONBLOCK)
    fcntl.fcntl(stream, fcntl.F_SETFL, flags)


set_blocking(stdout)
set_blocking(stderr)
