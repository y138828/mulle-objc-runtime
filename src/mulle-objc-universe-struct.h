//
//  mulle_objc_universe_struct.h
//  mulle-objc-runtime
//
//  Created by Nat! on 16/11/14.
//  Copyright (c) 2014 Nat! - Mulle kybernetiK.
//  Copyright (c) 2014 Codeon GmbH.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  Neither the name of Mulle kybernetiK nor the names of its contributors
//  may be used to endorse or promote products derived from this software
//  without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
#ifndef mulle_objc_universe_struct_h__
#define mulle_objc_universe_struct_h__

#include "mulle-objc-cache.h"
#include "mulle-objc-fastclasstable.h"
#include "mulle-objc-fastmethodtable.h"
#include "mulle-objc-ivarlist.h"
#include "mulle-objc-load.h"
#include "mulle-objc-methodlist.h"
#include "mulle-objc-propertylist.h"
#include "mulle-objc-taggedpointer.h"
#include "mulle-objc-uniqueid.h"
#include "mulle-objc-uniqueidarray.h"
#include "mulle-objc-super.h"
#include "mulle-objc-version.h"

#include "include.h"


struct _mulle_objc_class;
struct _mulle_objc_universe;
struct mulle_objc_loadversion;


//
// Config of the universe. Don't change after intialization
//
struct _mulle_objc_universeconfig
{
   unsigned   forget_strings           : 1;  // don't keep track of static strings
   unsigned   ignore_ivarhash_mismatch : 1;  // do not check for fragility problems
   unsigned   max_optlevel             : 3;  // max compiler optimization level: (7)
   unsigned   min_optlevel             : 3;  // min compiler optimization level: (0)
   unsigned   no_tagged_pointer        : 1;  // don't use tagged pointers
   unsigned   no_fast_call             : 1;  // don't use fast method calls
   unsigned   repopulate_caches        : 1;  // useful for coverage analysis

   int        cache_fillrate;                // default is (0) can be 0-90
};


// loadbits check that code we add to the universe is
// compatible with respect to tagged pointers
enum
{
   MULLE_OBJC_UNIVERSE_HAVE_NO_TPS_LOADS = 0x1,
   MULLE_OBJC_UNIVERSE_HAVE_TPS_LOADS    = 0x2,
   MULLE_OBJC_UNIVERSE_HAVE_TPS_CLASSES  = 0x4
};


//
// Debug the universe. Use environment variables to set these
// bits.
//
struct _mulle_objc_universedebug
{
   struct
   {
      unsigned   method_searches;      // keep this in an int

      unsigned   category_add         : 1;
      unsigned   class_add            : 1;
      unsigned   class_cache          : 1;
      unsigned   class_free           : 1;
      unsigned   dependency           : 1;
      unsigned   dump_universe        : 1;  // hefty, set manually
      unsigned   fastclass_add        : 1;
      unsigned   initialize           : 1;
      unsigned   hashstrings          : 1;
      unsigned   load_call            : 1; // +initialize, +load, +categoryDependencies
      unsigned   loadinfo             : 1;
      unsigned   method_cache         : 1;
      unsigned   method_call          : 1;
      unsigned   descriptor_add       : 1;
      unsigned   protocol_add         : 1;
      unsigned   state_bit            : 1;
      unsigned   string_add           : 1;
      unsigned   super_add            : 1;
      unsigned   tagged_pointer       : 1;
      unsigned   universe             : 1;
   } trace;

   struct
   {
      unsigned   methodid_type          : 1;
      unsigned   protocolclass          : 1;
      unsigned   stuck_loadable         : 1;  // set by default
      unsigned   pedantic_methodid_type : 1;
   } warn;

   struct
   {
      unsigned   universe_config         : 1;
      unsigned   print_origin            : 1; // set by default
      unsigned   stuck_class_coverage    : 1;
      unsigned   stuck_category_coverage : 1;
   } print;
};


//
// Objective-C exceptions and @try/@catch are vectored through here
//
struct _mulle_objc_universeexceptionvectors
{
   void   (*throw)( struct _mulle_objc_universe *universe, void *exception);
   void   (*try_enter)( struct _mulle_objc_universe *universe, void *localExceptionData);
   void   (*try_exit)( struct _mulle_objc_universe *universe, void *localExceptionData);
   void   *(*extract)( struct _mulle_objc_universe *universe, void *localExceptionData);
   int    (*match)( struct _mulle_objc_universe *universe, mulle_objc_classid_t classid, void *exception);
};


//
// Failures of the universe itself are vectored though here
//
struct _mulle_objc_universefailures
{
   void   (*uncaughtexception)( void *exception)         _MULLE_C_NO_RETURN;
   // fails in unfailing method -> abort
   void   (*fail)( char *format, va_list args)           _MULLE_C_NO_RETURN;
   // unexpected happening -> abort
   void   (*inconsistency)( char *format, va_list args)  _MULLE_C_NO_RETURN;
   // class not found -> abort
   void   (*classnotfound)( struct _mulle_objc_universe *universe,
                            mulle_objc_methodid_t missing_method)  _MULLE_C_NO_RETURN;
   // method not found -> abort
   void   (*methodnotfound)( struct _mulle_objc_universe *universe,
                             struct _mulle_objc_class *cls,
                             mulle_objc_methodid_t missing_method)  _MULLE_C_NO_RETURN;
   // super not found -> abort
   void   (*supernotfound)( struct _mulle_objc_universe *universe,
                            mulle_objc_superid_t missing_super)  _MULLE_C_NO_RETURN;
};


//
// Specify methodids (global) that get preloaded into the method caches.
// This guarantees an optimal spot and no delay during the first call.
// It makes no sense to put "fast" methods here...
//
struct _mulle_objc_preloadmethodids
{
   unsigned int            n;
   mulle_objc_methodid_t   methodids[ 32];
};


//
// Default values to be put into classes, when they are being created
//
struct _mulle_objc_classdefaults
{
   struct _mulle_objc_method   *forwardmethod;
   void                        (*class_is_missing)( struct _mulle_objc_universe *,
                                                    mulle_objc_classid_t);
   unsigned short              inheritance;
};


struct _mulle_objc_universecallbacks
{
   int    (*should_load_loadinfo)(  struct _mulle_objc_universe *,
                                    struct _mulle_objc_loadinfo *);

   mulle_objc_cache_uint_t   (*will_init_cache)(  struct _mulle_objc_universe *,
                                                  struct _mulle_objc_class *,
                                                  mulle_objc_cache_uint_t n_entries);
   void   (*will_dealloc)(  struct _mulle_objc_universe *);
};

//
// Garbage collection for the various caches
struct _mulle_objc_garbagecollection
{
   struct mulle_aba   aba;
};


typedef void   mulle_objc_universefriend_destructor_t( struct _mulle_objc_universe *, void *);
typedef void   mulle_objc_universefriend_versionassert_t( struct _mulle_objc_universe *,
                                                          void *,
                                                          struct mulle_objc_loadversion *);


//
// Give friends of the universe a place to store data. The universe will run
// the destructor upon closing. With the versionassert you can ensure that
// your friend is compatible with the currently loaded "loadinfo"
//
struct _mulle_objc_universefriend
{
   void                                         *data;
   mulle_objc_universefriend_destructor_t       *destructor;
   mulle_objc_universefriend_versionassert_t    *versionassert;
};

//
// Foundation information that the universe uses. The string class will place
// itself into the universe during +load using
// `_mulle_objc_universe_add_staticstring`. The allocator should be setup during
// the universe initialization.
// The postponer is used to wait for staticstring (or something else)

typedef int   mulle_objc_waitqueues_postpone_t( struct _mulle_objc_universe *,
                                                struct _mulle_objc_loadinfo *);

struct _mulle_objc_foundation
{
   struct _mulle_objc_universefriend    universefriend;
   struct _mulle_objc_infraclass        *staticstringclass;
   struct mulle_allocator               allocator;   // allocator for objects
   mulle_objc_classid_t                 rootclassid; // NSObject = e9e78cbd
};


struct _mulle_objc_memorymanagement
{
   struct mulle_allocator   allocator;
};


//
// Up to seven classes that tagged pointers are constructed for
// Classes register themselves for a certain index during load.
//
struct _mulle_objc_taggedpointers
{
   struct _mulle_objc_class    *pointerclass[ 8];         // only 1 ... are really used
};


struct _mulle_objc_waitqueues
{
   mulle_thread_mutex_t              lock;  // used for
   struct mulle_concurrent_hashmap   classestoload;
   struct mulle_concurrent_hashmap   categoriestoload;
};

// size in bytes
#define S_MULLE_OBJC_UNIVERSE_FOUNDATION_SPACE   1024

/*
 * All (?) global variables used by the universe are in this struct.
 * in fact if you setup the universe properly with a root
 * autorelease pool, you should be able to completely remove the
 * universe AND all created instances.
 *
 * All no, unfortunately there is one static class needed for
 * static strings.
 */
enum
{
   mulle_objc_universe_is_uninitialized  = -3,
   mulle_objc_universe_is_initializing   = -2,
   mulle_objc_universe_is_deinitializing = -1
};


struct _mulle_objc_universe
{
   //
   // A: these types are all designed to be concurrent, no locking needed
   //
   struct _mulle_objc_cachepivot            cachepivot;

   // try to keep this region stable for version checks

   mulle_atomic_pointer_t                   version;
   char                                     *path;

   // try to keep this region stable for callbacks

   struct mulle_concurrent_hashmap          classtable;  /// keep it here for debugger
   struct mulle_concurrent_hashmap          descriptortable;
   struct mulle_concurrent_hashmap          protocoltable;
   struct mulle_concurrent_hashmap          categorytable;
   struct mulle_concurrent_hashmap          supertable;
   struct mulle_concurrent_pointerarray     staticstrings;
   struct mulle_concurrent_pointerarray     hashnames;
   struct mulle_concurrent_pointerarray     gifts;  // external (!) allocations that we need to free

   struct _mulle_objc_universecallbacks     callbacks;

   // unstable region, edit at will

   struct _mulle_objc_waitqueues            waitqueues;

   struct _mulle_objc_fastclasstable        fastclasstable;
   struct _mulle_objc_taggedpointers        taggedpointers;

   mulle_atomic_pointer_t                   retaincount_1;
   mulle_atomic_pointer_t                   cachecount_1; // #1#
   mulle_atomic_pointer_t                   loadbits;
   mulle_thread_mutex_t                     lock;
   mulle_thread_tss_t                       threadkey;

   // these are 0 and NULL respectively for global and thread local
   mulle_objc_universeid_t                  universeid;
   char                                     *universename;

   //
   // B: the rest is intended to be read only (setup at init time)
   //    if you think you need to change something, use the lock
   //
   char                                     compilation[ 128];   // debugging

   mulle_thread_t                           thread;  // init-done thread

   struct _mulle_objc_memorymanagement      memory;

   struct _mulle_objc_classdefaults         classdefaults;
   struct _mulle_objc_garbagecollection     garbage;
   struct _mulle_objc_preloadmethodids      methodidstopreload;

   struct _mulle_objc_universefailures      failures;
   struct _mulle_objc_universeexceptionvectors   exceptionvectors;
   struct _mulle_objc_universeconfig        config;
   struct _mulle_objc_universedebug         debug;

   // It's all zeroes, so save some space with a union.
   // it would be "nicer" to have these in a const global
   // but due to windows, it's nicer to have a few globals
   // as possible
   //
   union
   {
      struct _mulle_objc_cache           empty_cache;
      struct _mulle_objc_ivarlist        empty_ivarlist;
      struct _mulle_objc_methodlist      empty_methodlist;
      struct _mulle_objc_propertylist    empty_propertylist;
      struct _mulle_objc_superlist       empty_superlist;
      struct _mulle_objc_uniqueidarray   empty_uniqueidarray;
   };

   //
   // this allows the foundation to come up during load without having to do
   // a malloc
   //
   struct _mulle_objc_universefriend     userinfo;    // for user programs

   //
   // it must be assured that foundationspace always trails foundation
   //
   struct _mulle_objc_foundation         foundation;  // for foundation
   intptr_t                              foundationspace[ S_MULLE_OBJC_UNIVERSE_FOUNDATION_SPACE / sizeof( intptr_t)];
};


static inline uint32_t
	_mulle_objc_universe_get_version( struct _mulle_objc_universe *universe)
{
   return( (uint32_t) (uintptr_t) _mulle_atomic_pointer_read( &universe->version));
}


static inline char   *
	_mulle_objc_universe_get_path( struct _mulle_objc_universe *universe)
{
   return( universe->path);
}

static inline char   *
	mulle_objc_universe_get_name( struct _mulle_objc_universe *universe)
{
	if( ! universe)
		return( "NULL");
   return( universe->universename ? universe->universename : "DEFAULT");
}


static inline mulle_objc_universeid_t
	_mulle_objc_universe_get_universeid( struct _mulle_objc_universe *universe)
{
   return( universe->universeid);
}



static inline mulle_thread_tss_t
   _mulle_objc_universe_get_threadkey( struct _mulle_objc_universe *universe)
{
   return( universe->threadkey);
}

// initialized is "ready for user code"
// this is what you use in __get_or_create should query
static inline int
	_mulle_objc_universe_is_initialized( struct _mulle_objc_universe *universe)
{
   return( (int32_t) _mulle_objc_universe_get_version( universe) >= 0);
}

// uninitialized is "ready for no code"
static inline int
	_mulle_objc_universe_is_uninitialized( struct _mulle_objc_universe *universe)
{
   return( (int32_t) _mulle_objc_universe_get_version( universe) ==
   						mulle_objc_universe_is_uninitialized);
}


// transitioning is "ready for init/dealloc code" danger!
static inline int
	_mulle_objc_universe_is_transitioning( struct _mulle_objc_universe *universe)
{
   switch( _mulle_objc_universe_get_version( universe))
   {
      case mulle_objc_universe_is_initializing   :
      case mulle_objc_universe_is_deinitializing :
         return( 1);
   }
   return( 0);
}


#pragma mark - non concurrent memory allocation

// use for universe stuff, like classes, methods, properties, ivars
MULLE_C_NON_NULL_RETURN static inline struct mulle_allocator *
   _mulle_objc_universe_get_allocator( struct _mulle_objc_universe *universe)
{
   return( &universe->memory.allocator);
}


//
// #1#: whenever a caches contents change, this variable should be incremented
//      if that is adhered to, then we can checkout the value before a
//      methodlist update and afterwards, and deduce if a costly cache flush
//      is necessary.
//

#endif
