# This module handles all memory allocation and deallocation for the entire
# JAPL ecosystem. Forcing the entire language to route memory allocation
# into a single module makes it easy to track how much memory we have allocated
# and simplifies the implementation of a garbage collector
