//
//  mulle_objc_object_convenience.h
//  mulle-objc
//
//  Created by Nat! on 11.03.15.
//  Copyright (c) 2015 Nat! - Mulle kybernetiK.
//  Copyright (c) 2015 Codeon GmbH.
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

//

#ifndef mulle_objc_object_convenience_h__
#define mulle_objc_object_convenience_h__

#include "mulle_objc_object.h"

#include "mulle_objc_class.h"


// methods on class shortcuts

static inline char   *_mulle_objc_object_get_isa_name( void *obj)
{
   return( _mulle_objc_class_get_name( _mulle_objc_object_get_isa( obj)));
}

static inline mulle_objc_methodimplementation_t   _mulle_objc_object_lookup_cached_implementation( void *obj,
                                                                                                 mulle_objc_methodid_t methodid)
{
   struct _mulle_objc_class   *cls;
   
   cls = _mulle_objc_object_get_isa( obj);
   return( _mulle_objc_class_lookup_cached_methodimplementation( cls, methodid));
}


static inline mulle_objc_methodimplementation_t   _mulle_objc_object_lookup_implementation( void *obj,
                                                                                                    mulle_objc_methodid_t methodid)
{
   struct _mulle_objc_class   *cls;
   
   cls = _mulle_objc_object_get_isa( obj);
   return( _mulle_objc_class_lookup_methodimplementation( cls, methodid));
}


static inline mulle_objc_methodimplementation_t   _mulle_objc_object_lookup_implementation_no_forward( void *obj,
                                                                                                              mulle_objc_methodid_t methodid)
{
   struct _mulle_objc_class   *cls;
   
   cls = _mulle_objc_object_get_isa( obj);
   return( _mulle_objc_class_lookup_methodimplementation_no_forward( cls, methodid));
}


static inline struct _mulle_objc_method   *_mulle_objc_object_lookup_method( void *obj,
                                                                             mulle_objc_methodid_t methodid)
{
   struct _mulle_objc_class   *cls;
   
   cls  = _mulle_objc_object_get_isa( obj);
   return( mulle_objc_class_search_method( cls, methodid));
}

#endif
