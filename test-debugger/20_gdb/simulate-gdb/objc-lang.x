/* Objective-C language support routines for GDB, the GNU debugger.

   Copyright (C) 2002-2020 Free Software Foundation, Inc.

   Contributed by Apple Computer, Inc.
   Written by Michael Snyder.

   This file is part of GDB.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#include "defs.h"
#include "symtab.h"
#include "gdbtypes.h"
#include "expression.h"
#include "parser-defs.h"
#include "language.h"
#include "varobj.h"
#include "c-lang.h"
#include "objc-lang.h"
#include "complaints.h"
#include "value.h"
#include "symfile.h"
#include "objfiles.h"
#include "target.h"		/* for target_has_execution */
#include "gdbcore.h"
#include "gdbcmd.h"
#include "frame.h"
#include "gdb_regex.h"
#include "regcache.h"
#include "block.h"
#include "infcall.h"
#include "valprint.h"
#include "cli/cli-utils.h"

#include <ctype.h>

#ifdef __cplusplus
# include <algorithm>
#endif


//
// This file has been changed to work with mulle-objc
//
// When compiled with #ifndef __cplusplus, then large parts of the code
// poisoned by C++ is removed and the remaining functions can be used
// in a test in mulle-objc-runtime/test-debugger/20_gdb/simulate-gdb
// as is. Just copy it there.
//

struct objc_object {
  CORE_ADDR isa;
};

struct objc_class {
  CORE_ADDR isa;
  CORE_ADDR super_class;
  CORE_ADDR name;
//  long version;
//  long info;
  long allocation_size;
//  CORE_ADDR ivars;
  CORE_ADDR methods;
//  CORE_ADDR cache;
  CORE_ADDR infra_class;
  CORE_ADDR universe;
//  CORE_ADDR protocols;
  long   classid;
  long   inheritance;
};

struct objc_super {
  long   classid;
  long   methodid;
};

struct objc_method {
  long      sel;
  CORE_ADDR name;
  CORE_ADDR types;
  CORE_ADDR imp;
};

#ifdef __cplusplus

static const struct objfile_key<unsigned int> objc_objfile_data;

/* Lookup a structure type named "struct NAME", visible in lexical
   block BLOCK.  If NOERR is nonzero, return zero if NAME is not
   suitably defined.  */

struct symbol *
lookup_struct_typedef (const char *name, const struct block *block, int noerr)
{
  struct symbol *sym;

  sym = lookup_symbol (name, block, STRUCT_DOMAIN, 0).symbol;

  if (sym == NULL)
    {
      if (noerr)
	return 0;
      else
	error (_("No struct type named %s."), name);
    }
  if (TYPE_CODE (SYMBOL_TYPE (sym)) != TYPE_CODE_STRUCT)
    {
      if (noerr)
	return 0;
      else
	error (_("This context has class, union or enum %s, not a struct."),
	       name);
    }
  return sym;
}

CORE_ADDR
lookup_objc_class (struct gdbarch *gdbarch, const char *classname)
{
  struct type *char_type = builtin_type (gdbarch)->builtin_char;
  struct value * function, *classval;

  if (! target_has_execution)
    {
      /* Can't call into inferior to lookup class.  */
      return 0;
    }

  if (lookup_minimal_symbol("objc_lookUpClass", 0, 0).minsym)
    function = find_function_in_inferior("objc_lookUpClass", NULL);
  else if (lookup_minimal_symbol ("objc_lookup_class", 0, 0).minsym)
    function = find_function_in_inferior("objc_lookup_class", NULL);
  else
    {
      complaint (_("no way to lookup Objective-C classes"));
      return 0;
    }

  classval = value_string (classname, strlen (classname) + 1, char_type);
  classval = value_coerce_array (classval);
  return (CORE_ADDR) value_as_long (call_function_by_hand (function,
							   NULL,
							   classval));
}

CORE_ADDR
lookup_child_selector (struct gdbarch *gdbarch, const char *selname)
{
  struct type *char_type = builtin_type (gdbarch)->builtin_char;
  struct value * function, *selstring;

  if (! target_has_execution)
    {
      /* Can't call into inferior to lookup selector.  */
      return 0;
    }

  if (lookup_minimal_symbol("sel_getUid", 0, 0).minsym)
    function = find_function_in_inferior("sel_getUid", NULL);
  else if (lookup_minimal_symbol ("sel_get_any_uid", 0, 0).minsym)
    function = find_function_in_inferior("sel_get_any_uid", NULL);
  else
    {
      complaint (_("no way to lookup Objective-C selectors"));
      return 0;
    }

  selstring = value_coerce_array (value_string (selname,
						strlen (selname) + 1,
						char_type));
  return value_as_long (call_function_by_hand (function, NULL, selstring));
}

struct value *
value_nsstring (struct gdbarch *gdbarch, char *ptr, int len)
{
  struct type *char_type = builtin_type (gdbarch)->builtin_char;
  struct value *stringValue[3];
  struct value *function, *nsstringValue;
  struct symbol *sym;
  struct type *type;

  if (!target_has_execution)
    return 0;		/* Can't call into inferior to create NSString.  */

  stringValue[2] = value_string(ptr, len, char_type);
  stringValue[2] = value_coerce_array(stringValue[2]);
  /* _NSNewStringFromCString replaces "istr" after Lantern2A.  */
  if (lookup_minimal_symbol("_NSNewStringFromCString", 0, 0).minsym)
    {
      function = find_function_in_inferior("_NSNewStringFromCString", NULL);
      nsstringValue = call_function_by_hand(function, NULL, stringValue[2]);
    }
  else if (lookup_minimal_symbol("istr", 0, 0).minsym)
    {
      function = find_function_in_inferior("istr", NULL);
      nsstringValue = call_function_by_hand(function, NULL, stringValue[2]);
    }
  else if (lookup_minimal_symbol("+[NSString stringWithCString:]", 0, 0).minsym)
    {
      function
	= find_function_in_inferior("+[NSString stringWithCString:]", NULL);
      type = builtin_type (gdbarch)->builtin_long;

      stringValue[0] = value_from_longest
	(type, lookup_objc_class (gdbarch, "NSString"));
      stringValue[1] = value_from_longest
	(type, lookup_child_selector (gdbarch, "stringWithCString:"));
      nsstringValue = call_function_by_hand(function, NULL, stringValue);
    }
  else
    error (_("NSString: internal error -- no way to create new NSString"));

  sym = lookup_struct_typedef("NSString", 0, 1);
  if (sym == NULL)
    sym = lookup_struct_typedef("NXString", 0, 1);
  if (sym == NULL)
    type = builtin_type (gdbarch)->builtin_data_ptr;
  else
    type = lookup_pointer_type(SYMBOL_TYPE (sym));

  deprecated_set_value_type (nsstringValue, type);
  return nsstringValue;
}

/* Objective-C name demangling.  */

char *
objc_demangle (const char *mangled, int options)
{
  char *demangled, *cp;

  if (mangled[0] == '_' &&
     (mangled[1] == 'i' || mangled[1] == 'c') &&
      mangled[2] == '_')
    {
      cp = demangled = (char *) xmalloc (strlen (mangled) + 2);

      if (mangled[1] == 'i')
	*cp++ = '-';		/* for instance method */
      else
	*cp++ = '+';		/* for class    method */

      *cp++ = '[';		/* opening left brace  */
      strcpy(cp, mangled+3);	/* Tack on the rest of the mangled name.  */

      while (*cp && *cp == '_')
	cp++;			/* Skip any initial underbars in class
				   name.  */

      cp = strchr(cp, '_');
      if (!cp)	                /* Find first non-initial underbar.  */
	{
	  xfree(demangled);	/* not mangled name */
	  return NULL;
	}
      if (cp[1] == '_')		/* Easy case: no category name.    */
	{
	  *cp++ = ' ';		/* Replace two '_' with one ' '.   */
	  strcpy(cp, mangled + (cp - demangled) + 2);
	}
      else
	{
	  *cp++ = '(';		/* Less easy case: category name.  */
	  cp = strchr(cp, '_');
	  if (!cp)
	    {
	      xfree(demangled);	/* not mangled name */
	      return NULL;
	    }
	  *cp++ = ')';
	  *cp++ = ' ';		/* Overwriting 1st char of method name...  */
	  strcpy(cp, mangled + (cp - demangled));	/* Get it back.  */
	}

      while (*cp && *cp == '_')
	cp++;			/* Skip any initial underbars in
				   method name.  */

      for (; *cp; cp++)
	if (*cp == '_')
	  *cp = ':';		/* Replace remaining '_' with ':'.  */

      *cp++ = ']';		/* closing right brace */
      *cp++ = 0;		/* string terminator */
      return demangled;
    }
  else
    return NULL;	/* Not an objc mangled name.  */
}

/* la_sniff_from_mangled_name for ObjC.  */

static int
objc_sniff_from_mangled_name (const char *mangled, char **demangled)
{
  *demangled = objc_demangle (mangled, 0);
  return *demangled != NULL;
}



/* Determine if we are currently in the Objective-C dispatch function.
   If so, get the address of the method function that the dispatcher
   would call and use that as the function to step into instead.  Also
   skip over the trampoline for the function (if any).  This is better
   for the user since they are only interested in stepping into the
   method function anyway.  */
static CORE_ADDR
objc_skip_trampoline (struct frame_info *frame, CORE_ADDR stop_pc)
{
  struct gdbarch *gdbarch = get_frame_arch (frame);
  CORE_ADDR real_stop_pc;
  CORE_ADDR method_stop_pc;

  real_stop_pc = gdbarch_skip_trampoline_code (gdbarch, frame, stop_pc);

  if (real_stop_pc != 0)
    find_objc_msgcall (real_stop_pc, &method_stop_pc);
  else
    find_objc_msgcall (stop_pc, &method_stop_pc);

  if (method_stop_pc)
    {
      real_stop_pc = gdbarch_skip_trampoline_code
		       (gdbarch, frame, method_stop_pc);
      if (real_stop_pc == 0)
	real_stop_pc = method_stop_pc;
    }

  return real_stop_pc;
}


/* Table mapping opcodes into strings for printing operators
   and precedences of the operators.  */

static const struct op_print objc_op_print_tab[] =
  {
    {",",  BINOP_COMMA, PREC_COMMA, 0},
    {"=",  BINOP_ASSIGN, PREC_ASSIGN, 1},
    {"||", BINOP_LOGICAL_OR, PREC_LOGICAL_OR, 0},
    {"&&", BINOP_LOGICAL_AND, PREC_LOGICAL_AND, 0},
    {"|",  BINOP_BITWISE_IOR, PREC_BITWISE_IOR, 0},
    {"^",  BINOP_BITWISE_XOR, PREC_BITWISE_XOR, 0},
    {"&",  BINOP_BITWISE_AND, PREC_BITWISE_AND, 0},
    {"==", BINOP_EQUAL, PREC_EQUAL, 0},
    {"!=", BINOP_NOTEQUAL, PREC_EQUAL, 0},
    {"<=", BINOP_LEQ, PREC_ORDER, 0},
    {">=", BINOP_GEQ, PREC_ORDER, 0},
    {">",  BINOP_GTR, PREC_ORDER, 0},
    {"<",  BINOP_LESS, PREC_ORDER, 0},
    {">>", BINOP_RSH, PREC_SHIFT, 0},
    {"<<", BINOP_LSH, PREC_SHIFT, 0},
    {"+",  BINOP_ADD, PREC_ADD, 0},
    {"-",  BINOP_SUB, PREC_ADD, 0},
    {"*",  BINOP_MUL, PREC_MUL, 0},
    {"/",  BINOP_DIV, PREC_MUL, 0},
    {"%",  BINOP_REM, PREC_MUL, 0},
    {"@",  BINOP_REPEAT, PREC_REPEAT, 0},
    {"-",  UNOP_NEG, PREC_PREFIX, 0},
    {"!",  UNOP_LOGICAL_NOT, PREC_PREFIX, 0},
    {"~",  UNOP_COMPLEMENT, PREC_PREFIX, 0},
    {"*",  UNOP_IND, PREC_PREFIX, 0},
    {"&",  UNOP_ADDR, PREC_PREFIX, 0},
    {"sizeof ", UNOP_SIZEOF, PREC_PREFIX, 0},
    {"++", UNOP_PREINCREMENT, PREC_PREFIX, 0},
    {"--", UNOP_PREDECREMENT, PREC_PREFIX, 0},
    {NULL, OP_NULL, PREC_NULL, 0}
};

static const char *objc_extensions[] =
{
// @mulle-objc@ file type .aam >
   ".aam",
// @mulle-objc@ file type .aam >
  ".m", NULL
};

extern const struct language_defn objc_language_defn = {
  "objective-c",		/* Language name */
  "Objective-C",
  language_objc,
  range_check_off,
  case_sensitive_on,
  array_row_major,
  macro_expansion_c,
  objc_extensions,
  &exp_descriptor_standard,
  c_parse,
  null_post_parser,
  c_printchar,		       /* Print a character constant */
  c_printstr,		       /* Function to print string constant */
  c_emit_char,
  c_print_type,			/* Print a type using appropriate syntax */
  c_print_typedef,		/* Print a typedef using appropriate syntax */
  c_value_print_inner,		/* la_value_print_inner */
  c_value_print,		/* Print a top-level value */
  default_read_var_value,	/* la_read_var_value */
  objc_skip_trampoline, 	/* Language specific skip_trampoline */
  "self",		        /* name_of_this */
  false,			/* la_store_sym_names_in_linkage_form_p */
  basic_lookup_symbol_nonlocal,	/* lookup_symbol_nonlocal */
  basic_lookup_transparent_type,/* lookup_transparent_type */
  objc_demangle,		/* Language specific symbol demangler */
  objc_sniff_from_mangled_name,
  NULL,				/* Language specific
				   class_name_from_physname */
  objc_op_print_tab,		/* Expression operators for printing */
  1,				/* C-style arrays */
  0,				/* String lower bound */
  default_word_break_characters,
  default_collect_symbol_completion_matches,
  c_language_arch_info,
  default_print_array_index,
  default_pass_by_reference,
  c_watch_location_expression,
  NULL,				/* la_get_symbol_name_matcher */
  iterate_over_symbols,
  default_search_name_hash,
  &default_varobj_ops,
  NULL,
  NULL,
  c_is_string_type_p,
  "{...}"			/* la_struct_too_deep_ellipsis */
};

/*
 * ObjC:
 * Following functions help construct Objective-C message calls.
 */

struct selname		/* For parsing Objective-C.  */
  {
    struct selname *next;
    char *msglist_sel;
    int msglist_len;
  };

static int msglist_len;
static struct selname *selname_chain;
static char *msglist_sel;

void
start_msglist(void)
{
  struct selname *newobj = XNEW (struct selname);

  newobj->next = selname_chain;
  newobj->msglist_len = msglist_len;
  newobj->msglist_sel = msglist_sel;
  msglist_len = 0;
  msglist_sel = (char *)xmalloc(1);
  *msglist_sel = 0;
  selname_chain = newobj;
}

void
add_msglist(struct stoken *str, int addcolon)
{
  char *s;
  const char *p;
  int len, plen;

  if (str == 0)			/* Unnamed arg, or...  */
    {
      if (addcolon == 0)	/* variable number of args.  */
	{
	  msglist_len++;
	  return;
	}
      p = "";
      plen = 0;
    }
  else
    {
      p = str->ptr;
      plen = str->length;
    }
  len = plen + strlen(msglist_sel) + 2;
  s = (char *)xmalloc(len);
  strcpy(s, msglist_sel);
  strncat(s, p, plen);
  xfree(msglist_sel);
  msglist_sel = s;
  if (addcolon)
    {
      s[len-2] = ':';
      s[len-1] = 0;
      msglist_len++;
    }
  else
    s[len-2] = '\0';
}

int
end_msglist (struct parser_state *ps)
{
  int val = msglist_len;
  struct selname *sel = selname_chain;
  char *p = msglist_sel;
  CORE_ADDR selid;

  selname_chain = sel->next;
  msglist_len = sel->msglist_len;
  msglist_sel = sel->msglist_sel;
  selid = lookup_child_selector (ps->gdbarch (), p);
  if (!selid)
    error (_("Can't find selector \"%s\""), p);
  write_exp_elt_longcst (ps, selid);
  xfree(p);
  write_exp_elt_longcst (ps, val);	/* Number of args */
  xfree(sel);

  return val;
}

/*
 * Function: specialcmp (const char *a, const char *b)
 *
 * Special strcmp: treats ']' and ' ' as end-of-string.
 * Used for qsorting lists of objc methods (either by class or selector).
 */

static int
specialcmp (const char *a, const char *b)
{
  while (*a && *a != ' ' && *a != ']' && *b && *b != ' ' && *b != ']')
    {
      if (*a != *b)
	return *a - *b;
      a++, b++;
    }
  if (*a && *a != ' ' && *a != ']')
    return  1;		/* a is longer therefore greater.  */
  if (*b && *b != ' ' && *b != ']')
    return -1;		/* a is shorter therefore lesser.  */
  return    0;		/* a and b are identical.  */
}

/*
 * Function: compare_selectors (const void *, const void *)
 *
 * Comparison function for use with qsort.  Arguments are symbols or
 * msymbols Compares selector part of objc method name alphabetically.
 */

static int
compare_selectors (const void *a, const void *b)
{
  const char *aname, *bname;

  aname = (*(struct symbol **) a)->print_name ();
  bname = (*(struct symbol **) b)->print_name ();
  if (aname == NULL || bname == NULL)
    error (_("internal: compare_selectors(1)"));

  aname = strchr(aname, ' ');
  bname = strchr(bname, ' ');
  if (aname == NULL || bname == NULL)
    error (_("internal: compare_selectors(2)"));

  return specialcmp (aname+1, bname+1);
}

/*
 * Function: selectors_info (regexp, from_tty)
 *
 * Implements the "Info selectors" command.  Takes an optional regexp
 * arg.  Lists all objective c selectors that match the regexp.  Works
 * by grepping thru all symbols for objective c methods.  Output list
 * is sorted and uniqued.
 */

static void
info_selectors_command (const char *regexp, int from_tty)
{
  const char            *name;
  char                  *val;
  int                    matches = 0;
  int                    maxlen  = 0;
  int                    ix;
  char                   myregexp[2048];
  char                   asel[256];
  struct symbol        **sym_arr;
  int                    plusminus = 0;

  if (regexp == NULL)
    strcpy(myregexp, ".*]");	/* Null input, match all objc methods.  */
  else
    {
      if (*regexp == '+' || *regexp == '-')
	{ /* User wants only class methods or only instance methods.  */
	  plusminus = *regexp++;
	  while (*regexp == ' ' || *regexp == '\t')
	    regexp++;
	}
      if (*regexp == '\0')
	strcpy(myregexp, ".*]");
      else
	{
	  /* Allow a few extra bytes because of the strcat below.  */
	  if (sizeof (myregexp) < strlen (regexp) + 4)
	    error (_("Regexp is too long: %s"), regexp);
	  strcpy(myregexp, regexp);
	  if (myregexp[strlen(myregexp) - 1] == '$') /* end of selector */
	    myregexp[strlen(myregexp) - 1] = ']';    /* end of method name */
	  else
	    strcat(myregexp, ".*]");
	}
    }

  if (regexp != NULL)
    {
      val = re_comp (myregexp);
      if (val != 0)
	error (_("Invalid regexp (%s): %s"), val, regexp);
    }

  /* First time thru is JUST to get max length and count.  */
  for (objfile *objfile : current_program_space->objfiles ())
    {
      for (minimal_symbol *msymbol : objfile->msymbols ())
	{
	  QUIT;
	  name = msymbol->natural_name ();
	  if (name
	      && (name[0] == '-' || name[0] == '+')
	      && name[1] == '[')		/* Got a method name.  */
	    {
	      /* Filter for class/instance methods.  */
	      if (plusminus && name[0] != plusminus)
		continue;
	      /* Find selector part.  */
	      name = (char *) strchr (name+2, ' ');
	      if (name == NULL)
		{
		  complaint (_("Bad method name '%s'"),
			     msymbol->natural_name ());
		  continue;
		}
	      if (regexp == NULL || re_exec(++name) != 0)
		{
		  const char *mystart = name;
		  const char *myend   = strchr (mystart, ']');

		  if (myend && (myend - mystart > maxlen))
		    maxlen = myend - mystart;	/* Get longest selector.  */
		  matches++;
		}
	    }
	}
    }
  if (matches)
    {
      printf_filtered (_("Selectors matching \"%s\":\n\n"),
		       regexp ? regexp : "*");

      sym_arr = XALLOCAVEC (struct symbol *, matches);
      matches = 0;
      for (objfile *objfile : current_program_space->objfiles ())
	{
	  for (minimal_symbol *msymbol : objfile->msymbols ())
	    {
	      QUIT;
	      name = msymbol->natural_name ();
	      if (name &&
		  (name[0] == '-' || name[0] == '+') &&
		  name[1] == '[')		/* Got a method name.  */
		{
		  /* Filter for class/instance methods.  */
		  if (plusminus && name[0] != plusminus)
		    continue;
		  /* Find selector part.  */
		  name = (char *) strchr(name+2, ' ');
		  if (regexp == NULL || re_exec(++name) != 0)
		    sym_arr[matches++] = (struct symbol *) msymbol;
		}
	    }
	}

      qsort (sym_arr, matches, sizeof (struct minimal_symbol *),
	     compare_selectors);
      /* Prevent compare on first iteration.  */
      asel[0] = 0;
      for (ix = 0; ix < matches; ix++)	/* Now do the output.  */
	{
	  char *p = asel;

	  QUIT;
	  name = sym_arr[ix]->natural_name ();
	  name = strchr (name, ' ') + 1;
	  if (p[0] && specialcmp(name, p) == 0)
	    continue;		/* Seen this one already (not unique).  */

	  /* Copy selector part.  */
	  while (*name && *name != ']')
	    *p++ = *name++;
	  *p++ = '\0';
	  /* Print in columns.  */
	  puts_filtered_tabular(asel, maxlen + 1, 0);
	}
      begin_line();
    }
  else
    printf_filtered (_("No selectors matching \"%s\"\n"),
		     regexp ? regexp : "*");
}

/*
 * Function: compare_classes (const void *, const void *)
 *
 * Comparison function for use with qsort.  Arguments are symbols or
 * msymbols Compares class part of objc method name alphabetically.
 */

static int
compare_classes (const void *a, const void *b)
{
  const char *aname, *bname;

  aname = (*(struct symbol **) a)->print_name ();
  bname = (*(struct symbol **) b)->print_name ();
  if (aname == NULL || bname == NULL)
    error (_("internal: compare_classes(1)"));

  return specialcmp (aname+1, bname+1);
}

/*
 * Function: classes_info(regexp, from_tty)
 *
 * Implements the "info classes" command for objective c classes.
 * Lists all objective c classes that match the optional regexp.
 * Works by grepping thru the list of objective c methods.  List will
 * be sorted and uniqued (since one class may have many methods).
 * BUGS: will not list a class that has no methods.
 */

static void
info_classes_command (const char *regexp, int from_tty)
{
  const char            *name;
  char                  *val;
  int                    matches = 0;
  int                    maxlen  = 0;
  int                    ix;
  char                   myregexp[2048];
  char                   aclass[256];
  struct symbol        **sym_arr;

  if (regexp == NULL)
    strcpy(myregexp, ".* ");	/* Null input: match all objc classes.  */
  else
    {
      /* Allow a few extra bytes because of the strcat below.  */
      if (sizeof (myregexp) < strlen (regexp) + 4)
	error (_("Regexp is too long: %s"), regexp);
      strcpy(myregexp, regexp);
      if (myregexp[strlen(myregexp) - 1] == '$')
	/* In the method name, the end of the class name is marked by ' '.  */
	myregexp[strlen(myregexp) - 1] = ' ';
      else
	strcat(myregexp, ".* ");
    }

  if (regexp != NULL)
    {
      val = re_comp (myregexp);
      if (val != 0)
	error (_("Invalid regexp (%s): %s"), val, regexp);
    }

  /* First time thru is JUST to get max length and count.  */
  for (objfile *objfile : current_program_space->objfiles ())
    {
      for (minimal_symbol *msymbol : objfile->msymbols ())
	{
	  QUIT;
	  name = msymbol->natural_name ();
	  if (name &&
	      (name[0] == '-' || name[0] == '+') &&
	      name[1] == '[')			/* Got a method name.  */
	    if (regexp == NULL || re_exec(name+2) != 0)
	      {
		/* Compute length of classname part.  */
		const char *mystart = name + 2;
		const char *myend   = strchr (mystart, ' ');

		if (myend && (myend - mystart > maxlen))
		  maxlen = myend - mystart;
		matches++;
	      }
	}
    }
  if (matches)
    {
      printf_filtered (_("Classes matching \"%s\":\n\n"),
		       regexp ? regexp : "*");
      sym_arr = XALLOCAVEC (struct symbol *, matches);
      matches = 0;
      for (objfile *objfile : current_program_space->objfiles ())
	{
	  for (minimal_symbol *msymbol : objfile->msymbols ())
	    {
	      QUIT;
	      name = msymbol->natural_name ();
	      if (name &&
		  (name[0] == '-' || name[0] == '+') &&
		  name[1] == '[') /* Got a method name.  */
		if (regexp == NULL || re_exec(name+2) != 0)
		  sym_arr[matches++] = (struct symbol *) msymbol;
	    }
	}

      qsort (sym_arr, matches, sizeof (struct minimal_symbol *),
	     compare_classes);
      /* Prevent compare on first iteration.  */
      aclass[0] = 0;
      for (ix = 0; ix < matches; ix++)	/* Now do the output.  */
	{
	  char *p = aclass;

	  QUIT;
	  name = sym_arr[ix]->natural_name ();
	  name += 2;
	  if (p[0] && specialcmp(name, p) == 0)
	    continue;	/* Seen this one already (not unique).  */

	  /* Copy class part of method name.  */
	  while (*name && *name != ' ')
	    *p++ = *name++;
	  *p++ = '\0';
	  /* Print in columns.  */
	  puts_filtered_tabular(aclass, maxlen + 1, 0);
	}
      begin_line();
    }
  else
    printf_filtered (_("No classes matching \"%s\"\n"), regexp ? regexp : "*");
}

static char *
parse_selector (char *method, char **selector)
{
  char *s1 = NULL;
  char *s2 = NULL;
  int found_quote = 0;

  char *nselector = NULL;

  gdb_assert (selector != NULL);

  s1 = method;

  s1 = skip_spaces (s1);
  if (*s1 == '\'')
    {
      found_quote = 1;
      s1++;
    }
  s1 = skip_spaces (s1);

  nselector = s1;
  s2 = s1;

  for (;;)
    {
      if (isalnum (*s2) || (*s2 == '_') || (*s2 == ':'))
	*s1++ = *s2;
      else if (isspace (*s2))
	;
      else if ((*s2 == '\0') || (*s2 == '\''))
	break;
      else
	return NULL;
      s2++;
    }
  *s1++ = '\0';

  s2 = skip_spaces (s2);
  if (found_quote)
    {
      if (*s2 == '\'')
	s2++;
      s2 = skip_spaces (s2);
    }

  if (selector != NULL)
    *selector = nselector;

  return s2;
}

static char *
parse_method (char *method, char *type, char **theclass,
	      char **category, char **selector)
{
  char *s1 = NULL;
  char *s2 = NULL;
  int found_quote = 0;

  char ntype = '\0';
  char *nclass = NULL;
  char *ncategory = NULL;
  char *nselector = NULL;

  gdb_assert (type != NULL);
  gdb_assert (theclass != NULL);
  gdb_assert (category != NULL);
  gdb_assert (selector != NULL);

  s1 = method;

  s1 = skip_spaces (s1);
  if (*s1 == '\'')
    {
      found_quote = 1;
      s1++;
    }
  s1 = skip_spaces (s1);

  if ((s1[0] == '+') || (s1[0] == '-'))
    ntype = *s1++;

  s1 = skip_spaces (s1);

  if (*s1 != '[')
    return NULL;
  s1++;

  nclass = s1;
  while (isalnum (*s1) || (*s1 == '_'))
    s1++;

  s2 = s1;
  s2 = skip_spaces (s2);

  if (*s2 == '(')
    {
      s2++;
      s2 = skip_spaces (s2);
      ncategory = s2;
      while (isalnum (*s2) || (*s2 == '_'))
	s2++;
      *s2++ = '\0';
    }

  /* Truncate the class name now that we're not using the open paren.  */
  *s1++ = '\0';

  nselector = s2;
  s1 = s2;

  for (;;)
    {
      if (isalnum (*s2) || (*s2 == '_') || (*s2 == ':'))
	*s1++ = *s2;
      else if (isspace (*s2))
	;
      else if (*s2 == ']')
	break;
      else
	return NULL;
      s2++;
    }
  *s1++ = '\0';
  s2++;

  s2 = skip_spaces (s2);
  if (found_quote)
    {
      if (*s2 != '\'')
	return NULL;
      s2++;
      s2 = skip_spaces (s2);
    }

  if (type != NULL)
    *type = ntype;
  if (theclass != NULL)
    *theclass = nclass;
  if (category != NULL)
    *category = ncategory;
  if (selector != NULL)
    *selector = nselector;

  return s2;
}

static void
find_methods (char type, const char *theclass, const char *category,
	      const char *selector,
	      std::vector<const char *> *symbol_names)
{
  const char *symname = NULL;

  char ntype = '\0';
  char *nclass = NULL;
  char *ncategory = NULL;
  char *nselector = NULL;

  static char *tmp = NULL;
  static unsigned int tmplen = 0;

  gdb_assert (symbol_names != NULL);

  for (objfile *objfile : current_program_space->objfiles ())
    {
      unsigned int *objc_csym;

      /* The objfile_csym variable counts the number of ObjC methods
	 that this objfile defines.  We save that count as a private
	 objfile data.	If we have already determined that this objfile
	 provides no ObjC methods, we can skip it entirely.  */

      unsigned int objfile_csym = 0;

      objc_csym = objc_objfile_data.get (objfile);
      if (objc_csym != NULL && *objc_csym == 0)
	/* There are no ObjC symbols in this objfile.  Skip it entirely.  */
	continue;

      for (minimal_symbol *msymbol : objfile->msymbols ())
	{
	  QUIT;

	  /* Check the symbol name first as this can be done entirely without
	     sending any query to the target.  */
	  symname = msymbol->natural_name ();
	  if (symname == NULL)
	    continue;

	  if ((symname[0] != '-' && symname[0] != '+') || (symname[1] != '['))
	    /* Not a method name.  */
	    continue;

	  objfile_csym++;

	  /* Now that thinks are a bit sane, clean up the symname.  */
	  while ((strlen (symname) + 1) >= tmplen)
	    {
	      tmplen = (tmplen == 0) ? 1024 : tmplen * 2;
	      tmp = (char *) xrealloc (tmp, tmplen);
	    }
	  strcpy (tmp, symname);

	  if (parse_method (tmp, &ntype, &nclass,
			    &ncategory, &nselector) == NULL)
	    continue;

	  if ((type != '\0') && (ntype != type))
	    continue;

	  if ((theclass != NULL)
	      && ((nclass == NULL) || (strcmp (theclass, nclass) != 0)))
	    continue;

	  if ((category != NULL) &&
	      ((ncategory == NULL) || (strcmp (category, ncategory) != 0)))
	    continue;

	  if ((selector != NULL) &&
	      ((nselector == NULL) || (strcmp (selector, nselector) != 0)))
	    continue;

	  symbol_names->push_back (symname);
	}

      if (objc_csym == NULL)
	objc_csym = objc_objfile_data.emplace (objfile, objfile_csym);
      else
	/* Count of ObjC methods in this objfile should be constant.  */
	gdb_assert (*objc_csym == objfile_csym);
    }
}

/* Uniquify a vector of strings.  */

static void
uniquify_strings (std::vector<const char *> *strings)
{
  if (strings->empty ())
    return;

  std::sort (strings->begin (), strings->end (), compare_cstrings);
  strings->erase (std::unique (strings->begin (), strings->end (), streq),
		  strings->end ());
}

/*
 * Function: find_imps (const char *selector, struct symbol **sym_arr)
 *
 * Input:  a string representing a selector
 *         a pointer to an array of symbol pointers
 *         possibly a pointer to a symbol found by the caller.
 *
 * Output: number of methods that implement that selector.  Side
 * effects: The array of symbol pointers is filled with matching syms.
 *
 * By analogy with function "find_methods" (symtab.c), builds a list
 * of symbols matching the ambiguous input, so that "decode_line_2"
 * (symtab.c) can list them and ask the user to choose one or more.
 * In this case the matches are objective c methods
 * ("implementations") matching an objective c selector.
 *
 * Note that it is possible for a normal (c-style) function to have
 * the same name as an objective c selector.  To prevent the selector
 * from eclipsing the function, we allow the caller (decode_line_1) to
 * search for such a function first, and if it finds one, pass it in
 * to us.  We will then integrate it into the list.  We also search
 * for one here, among the minsyms.
 *
 * NOTE: if NUM_DEBUGGABLE is non-zero, the sym_arr will be divided
 *       into two parts: debuggable (struct symbol) syms, and
 *       non_debuggable (struct minimal_symbol) syms.  The debuggable
 *       ones will come first, before NUM_DEBUGGABLE (which will thus
 *       be the index of the first non-debuggable one).
 */

const char *
find_imps (const char *method, std::vector<const char *> *symbol_names)
{
  char type = '\0';
  char *theclass = NULL;
  char *category = NULL;
  char *selector = NULL;

  char *buf = NULL;
  char *tmp = NULL;

  int selector_case = 0;

  gdb_assert (symbol_names != NULL);

  buf = (char *) alloca (strlen (method) + 1);
  strcpy (buf, method);
  tmp = parse_method (buf, &type, &theclass, &category, &selector);

  if (tmp == NULL)
    {
      strcpy (buf, method);
      tmp = parse_selector (buf, &selector);

      if (tmp == NULL)
	return NULL;

      selector_case = 1;
    }

  find_methods (type, theclass, category, selector, symbol_names);

  /* If we hit the "selector" case, and we found some methods, then
     add the selector itself as a symbol, if it exists.  */
  if (selector_case && !symbol_names->empty ())
    {
      struct symbol *sym = lookup_symbol (selector, NULL, VAR_DOMAIN,
					  0).symbol;

      if (sym != NULL)
	symbol_names->push_back (sym->natural_name ());
      else
	{
	  struct bound_minimal_symbol msym
	    = lookup_minimal_symbol (selector, 0, 0);

	  if (msym.minsym != NULL)
	    symbol_names->push_back (msym.minsym->natural_name ());
	}
    }

  uniquify_strings (symbol_names);

  return method + (tmp - buf);
}

static void
print_object_command (const char *args, int from_tty)
{
  struct value *object, *function, *description;
  CORE_ADDR string_addr, object_addr;
  int i = 0;
  gdb_byte c = 0;

  if (!args || !*args)
    error (
"The 'print-object' command requires an argument (an Objective-C object)");

  {
    expression_up expr = parse_expression (args);
    int pc = 0;

    object = evaluate_subexp (builtin_type (expr->gdbarch)->builtin_data_ptr,
			      expr.get (), &pc, EVAL_NORMAL);
  }

  /* Validate the address for sanity.  */
  object_addr = value_as_long (object);
  if( ! (object_addr & 0x1)) // don't do this if its TPS
     read_memory (object_addr, &c, 1);

  function = find_function_in_inferior ("_NSPrintForDebugger", NULL);
  if (function == NULL)
    error (_("Unable to locate _NSPrintForDebugger in child process"));

  description = call_function_by_hand (function, NULL, object);

  string_addr = value_as_long (description);
  if (string_addr == 0)
    error (_("object returns null description"));

  read_memory (string_addr + i++, &c, 1);
  if (c != 0)
    do
      { /* Read and print characters up to EOS.  */
	QUIT;
	printf_filtered ("%c", c);
	read_memory (string_addr + i++, &c, 1);
      } while (c != 0);
  else
    printf_filtered(_("<object returns empty description>"));
  printf_filtered ("\n");
}


void _initialize_objc_language ();
void
_initialize_objc_language ()
{
  add_info ("selectors", info_selectors_command,
       _("All Objective-C selectors, or those matching REGEXP."));
  add_info ("classes", info_classes_command,
       _("All Objective-C classes, or those matching REGEXP."));
  add_com ("print-object", class_vars, print_object_command,
      _("Ask an Objective-C object to print itself."));
  add_com_alias ("po", "print-object", class_vars, 1);
}

#endif // #ifdef __cplusplus



static void
read_objc_method (struct gdbarch *gdbarch, CORE_ADDR addr,
		  struct objc_method *method)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
  // @mulle-objc@ fix size >
  int   len;

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) addr);

  len           = gdbarch_ptr_bit( gdbarch) / 8;

  // this is really a uint32_t so.... lets read 4 only but assume ptr
  // alignment, runtime should make this explicit!
  method->sel   = read_memory_unsigned_integer (addr, 4, byte_order);
  addr += len;
  method->types = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len;
  method->name  = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len;

  addr += len; // skip bits
  method->imp   = read_memory_unsigned_integer (addr, len, byte_order);

  // fprintf( stderr, "%s :: sel   = %p\n", __PRETTY_FUNCTION__, (void *) method->sel );
  // fprintf( stderr, "%s :: types = %p\n", __PRETTY_FUNCTION__, (void *) method->types);
  // fprintf( stderr, "%s :: name  = %p\n", __PRETTY_FUNCTION__, (void *) method->name);
  // fprintf( stderr, "%s :: imp   = %p\n", __PRETTY_FUNCTION__, (void *) method->imp);
}

static unsigned long
read_objc_methlist_nmethods (struct gdbarch *gdbarch, CORE_ADDR addr)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
  // @mulle-objc@ fix size >
  int   len;

  len = gdbarch_ptr_bit( gdbarch) / 8;
  return read_memory_unsigned_integer(addr, len, byte_order);
  // @mulle-obcj@ fix size <
}

static void
read_objc_methlist_method (struct gdbarch *gdbarch, CORE_ADDR addr,
			   unsigned long num, struct objc_method *method)
{
  gdb_assert (num < read_objc_methlist_nmethods (gdbarch, addr));
  // @mulle-objc@ fix size >
  int   len;

  // fprintf( stderr, "%s :: %p %ld\n", __PRETTY_FUNCTION__, (void *) addr, num);

  len = gdbarch_ptr_bit( gdbarch) / 8;
  // @mulle-objc@ fix size >
  read_objc_method (gdbarch, addr + len * 2 + (5 * len * num), method);
}


static CORE_ADDR
read_universe( void)
{
   struct bound_minimal_symbol universe_sym;
   CORE_ADDR universe;

   universe_sym = lookup_bound_minimal_symbol("mulle_objc_defaultuniverse");
   if( ! universe_sym.minsym)
    universe_sym = lookup_bound_minimal_symbol("_mulle_objc_defaultuniverse");

   if( ! universe_sym.minsym)
   {
    // fprintf( stderr, "%s :: universe not found\n", __PRETTY_FUNCTION__);
    return ( 0);
   }

   universe = BMSYMBOL_VALUE_ADDRESS (universe_sym);
   return( universe);
}


static void
read_objc_object (struct gdbarch *gdbarch, CORE_ADDR addr,
		  struct objc_object *object)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
  int   len;
  int   tpsIndex;

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) addr);

  len = gdbarch_ptr_bit( gdbarch) / 8;

  if( ! (addr & 0x1))
  {
     addr = addr - len;
     object->isa = read_memory_unsigned_integer(addr, len, byte_order);
     return;
  }
   // it's a TPS instance! Get the mulle_objc_defaultuniverse
   CORE_ADDR universe;
   CORE_ADDR tpsTable;

   universe = read_universe();
   if( ! universe)
   {
      // fprintf( stderr, "%s :: universe not found\n", __PRETTY_FUNCTION__);
      memset( object, 0, sizeof( *object));
      return;
   }


   // fprintf( stderr, "%s :: universe=%p\n", __PRETTY_FUNCTION__, (void *) universe);
   // now get to TPS table
   tpsTable = universe;
   tpsTable += len; // skip cache
   tpsTable += 2 * len; // skip version + path

   tpsTable += 5 * (3 * len); // skip 5 hashmaps
   tpsTable += 3 * (3 * len); // skip 5 pointerarrays

   // fprintf( stderr, "%s :: tpsTable=%p\n", __PRETTY_FUNCTION__, (void *) tpsTable);
   tpsIndex = addr & (len == 8 ? 0x7 : 0x3);
   // fprintf( stderr, "%s :: tpsIndex=%d\n", __PRETTY_FUNCTION__, tpsIndex);

   object->isa = read_memory_unsigned_integer( tpsTable + tpsIndex * len, len, byte_order);
}


static void
read_objc_super (struct gdbarch *gdbarch, CORE_ADDR addr,
		 struct objc_super *super)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
  int   len;

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) addr);

  len = gdbarch_ptr_bit( gdbarch) / 8;
  // clearly non optimally alignment reading...
  super->classid  = read_memory_unsigned_integer (addr + 2 * len, 4, byte_order);
  // fprintf( stderr, "%s :: classid=%p\n", __PRETTY_FUNCTION__, (void *) super->classid);
  super->methodid = read_memory_unsigned_integer (addr + 2 * len + 4, 4, byte_order);
  // fprintf( stderr, "%s :: methodid=%p\n", __PRETTY_FUNCTION__, (void *) super->methodid);
};


static CORE_ADDR
search_hashtable(struct gdbarch *gdbarch, CORE_ADDR addr,
                 CORE_ADDR search)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
// @mulle-objc@ fix isa offset >
  int   len;

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) addr);

  len = gdbarch_ptr_bit( gdbarch) / 8;

  CORE_ADDR  storage;

  storage = read_memory_unsigned_integer( addr, len, byte_order);
  // fprintf( stderr, "%s :: storage=%p\n", __PRETTY_FUNCTION__,  (void *) storage);
  if( ! storage)
     return( 0);

  CORE_ADDR  nhashs;

  nhashs = read_memory_unsigned_integer( storage, len, byte_order);
  // fprintf( stderr, "%s :: nhashs=%p\n", __PRETTY_FUNCTION__,  (void *) nhashs);
  if( ! nhashs)
     return( 0);

  CORE_ADDR  key;
  CORE_ADDR  value;
  CORE_ADDR  mask;
  CORE_ADDR  entries;
  CORE_ADDR  endEntries;

  mask   = read_memory_unsigned_integer( storage + len, len, byte_order);
  // fprintf( stderr, "%s :: mask=%p\n", __PRETTY_FUNCTION__,  (void *) mask);

  entries    = storage + len * 2;
  endEntries = entries + len * 2 * mask;
  while( entries <= endEntries)
  {
    key      = read_memory_unsigned_integer( entries, len, byte_order);
    entries += len;
    //if( key)
    //   fprintf( stderr, "%s :: key=%p\n", __PRETTY_FUNCTION__, (void *) key);

    if( search == key)
    {
       value = read_memory_unsigned_integer( entries, len, byte_order);
       // fprintf( stderr, "%s :: value=%p\n", __PRETTY_FUNCTION__, (void *)  value);
       return( value);
    }
    entries += len;
  }
  return( 0);
}


// @mulle-objc@ read class
// struct _mulle_objc_methodcachepivot
// {
//    struct _mulle_objc_cachepivot   pivot; // for atomic XCHG with pointer indirection
//    mulle_objc_implementation_t     call2;
// };
// struct _mulle_objc_class
// {
//    struct _mulle_objc_methodcachepivot    cachepivot;  // DON'T MOVE
//
//    void                                   *(*call)( void *,
//                                                     mulle_objc_methodid_t,
//                                                     void *,
//                                                     struct _mulle_objc_class *);
//
//    /* ^^^ keep above like this, or change mulle_objc_fastmethodtable fault */
//
//    // keep name, superclass, allocationsize in this order for lldb debugging
//
//    struct _mulle_objc_class                *superclass;      // keep here for debugger (void **)[ 3]
//    char                                    *name;            // offset (void **)[ 4]
//    uintptr_t                               allocationsize;   // instancesize + header   (void **)[ 5]
//
//    struct mulle_concurrent_pointerarray    methodlists;
//
//    // vvv - from here on the debugger doesn't care


static void
read_objc_class (struct gdbarch *gdbarch, CORE_ADDR addr,
		 struct objc_class *theclass)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
// @mulle-objc@  >
  int   len;

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) addr);

  len = gdbarch_ptr_bit( gdbarch) / 8;

  theclass->isa = read_memory_unsigned_integer (addr - len, len, byte_order);

  addr += len * (2 + 1); // skip cachepivot + call

  theclass->super_class = read_memory_unsigned_integer (addr , len, byte_order);
  addr += len;

  theclass->name = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len;

  theclass->allocation_size = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len;

  // fprintf( stderr, "%s :: &method_lists=%p\n", __PRETTY_FUNCTION__, (void *) addr);
  theclass->methods = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len * 3;

  theclass->infra_class = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len;

  theclass->universe = read_memory_unsigned_integer (addr, len, byte_order);
  addr += len;

  theclass->classid = read_memory_unsigned_integer(addr, 4, byte_order);
  addr += 4;

//  theclass->superclassid = read_memory_unsigned_integer(addr, 4, byte_order);
  addr += 4;

  theclass->inheritance = read_memory_unsigned_integer(addr, 2, byte_order);
//  addr += 2;

// fprintf( stderr, "%s :: method_lists->storage.storage=%p\n", __PRETTY_FUNCTION__, (void *) theclass->methods);
//  theclass->ivars = read_memory_unsigned_integer (addr + 24, 4, byte_order);
//  theclass->cache = read_memory_unsigned_integer (addr + 32, 4, byte_order);
//  theclass->protocols = read_memory_unsigned_integer (addr + 36, 4, byte_order);
// @mulle-objc@  <

  // small sanity checks
  if( theclass->inheritance >= 0x20 ||
      theclass->classid == 0 || theclass->classid == -1 ||
      theclass->allocation_size < 0)
  {
      memset( theclass, 0, sizeof( *theclass));
  }
}




enum
{
   MULLE_OBJC_CLASS_DONT_INHERIT_SUPERCLASS          = 0x01,
   MULLE_OBJC_CLASS_DONT_INHERIT_CATEGORIES          = 0x02,
   MULLE_OBJC_CLASS_DONT_INHERIT_PROTOCOLS           = 0x04,
   MULLE_OBJC_CLASS_DONT_INHERIT_PROTOCOL_CATEGORIES = 0x08,
   MULLE_OBJC_CLASS_DONT_INHERIT_PROTOCOL_META       = 0x10,
};

static unsigned long
read_objc_pointerarray_count(struct gdbarch *gdbarch, CORE_ADDR addr)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
  // @mulle-objc@ fix size >
  int   len;

  len = gdbarch_ptr_bit( gdbarch) / 8;
  return read_memory_unsigned_integer( addr, len, byte_order);
  // @mulle-obcj@ fix size <
}


static CORE_ADDR
read_objc_pointerarray_entry(struct gdbarch *gdbarch,
                             CORE_ADDR addr,
                             unsigned long num)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);

  gdb_assert (num < read_objc_methlist_nmethods (gdbarch, addr));
  int   len;

  // fprintf( stderr, "%s :: %p %ld\n", __PRETTY_FUNCTION__, (void *) addr, num);

  len = gdbarch_ptr_bit( gdbarch) / 8;
  addr += len * 2;  // entrie
  return read_memory_unsigned_integer( addr + (num * len), len, byte_order);
}

/* x86_64: magic offsets, address arithmetic in mulle_objc_classpair
 * pair.infraclass      = 16
 * pair.metaclass       = 480
 * pair.protocolclasses = 824
 */
static inline CORE_ADDR
metaclass_of_infraclass( struct gdbarch *gdbarch,
                         CORE_ADDR infraAddr)
{
  if( gdbarch_ptr_bit( gdbarch) == 64)
     return( infraAddr + 480 - 16);
  return( 0);
}


// static inline CORE_ADDR
// infraclass_of_metaclass( struct gdbarch *gdbarch,
//                          CORE_ADDR metaAddr)
// {
//   if( gdbarch_ptr_bit( gdbarch) == 64)
//      return( metaAddr - 480 + 16);
//   return( 0);
// }


//
// just after the metaclass we run into the classpair struct with
// the protocolclasses conveniently at this point. It contains
// a pointer to the storage, which we read
static inline CORE_ADDR
protocolclass_array_of_metaclass( struct gdbarch *gdbarch,
                                  CORE_ADDR metaAddr)
{
  enum bfd_endian byte_order = gdbarch_byte_order (gdbarch);
  int   len;

  len = gdbarch_ptr_bit( gdbarch) / 8;
  if( gdbarch_ptr_bit( gdbarch) == 64)
     return( read_memory_unsigned_integer( metaAddr + 824 - 480, len, byte_order));

  return( 0);
}


static CORE_ADDR
search_superclass( struct gdbarch *gdbarch,
                   CORE_ADDR classAddr,
                   struct objc_class *p_class,
                   CORE_ADDR inheritance)
{
   struct objc_class   superclass_str;
   CORE_ADDR           supercls;

   if( inheritance & MULLE_OBJC_CLASS_DONT_INHERIT_SUPERCLASS)
      return( 0);

   supercls = p_class->super_class;
   if( ! p_class->infra_class)     // is a infra, (so has no infra companion, only meta)
      return( supercls);

   read_objc_class( gdbarch, supercls, &superclass_str);
   if( superclass_str.isa == 0)
      return( 0);
   if( superclass_str.infra_class) // is superclass a meta
      return( supercls);

   if( ! (inheritance & MULLE_OBJC_CLASS_DONT_INHERIT_PROTOCOL_META))
   {
      // Ok we'd be transitioning from metaclass to infraclass
      // Use protocolclass if available
      CORE_ADDR      protocolclassesAddr;
      CORE_ADDR      protoclassAddr;
      CORE_ADDR      protoclassMetaAddr;
      unsigned long  i, n;

      protocolclassesAddr = protocolclass_array_of_metaclass( gdbarch, classAddr);

      // get storage


      // first entry after meta is then the protocol classes array
      // in class pair (nota reverse enumeration here)
      n = read_objc_pointerarray_count( gdbarch, protocolclassesAddr);
      for( i = 0; i < n; i++)
      {
         protoclassAddr = read_objc_pointerarray_entry( gdbarch,
                                                        protocolclassesAddr,
                                                        i);
         if( ! protoclassAddr)
            break;

         protoclassMetaAddr = metaclass_of_infraclass( gdbarch, protoclassAddr);
         if( protoclassMetaAddr != classAddr)
         {
            supercls = protoclassMetaAddr;
            break;
         }
      }
   }
   return( supercls);
}


// @mulle-objc@ we are traversing at first a pointer to  a
// struct _mulle_concurrent_pointerarraystorage
// {
//    mulle_atomic_pointer_t   n;
//    uintptr_t                size;
//
//    mulle_atomic_pointer_t   entries[ 1];
// };


//
// TODO: need to reimplement the complete searching logic from
//       the runtime here....
//
static CORE_ADDR
find_implementation_in_methodlist(struct gdbarch *gdbarch,
                                  CORE_ADDR mlist,
                                  CORE_ADDR sel)
{
  // fprintf( stderr, "%s :: %p %p\n", __PRETTY_FUNCTION__, (void *) mlist, (void *)sel);
  unsigned long nmethods;
  unsigned long i;
  struct objc_method meth_str;

  nmethods = read_objc_methlist_nmethods (gdbarch, mlist);
  // fprintf( stderr, "%s :: nmethods=%p\n", __PRETTY_FUNCTION__, (void *) nmethods);

  for (i = 0; i < nmethods; i++)
  {
     read_objc_methlist_method( gdbarch, mlist, i, &meth_str);

     if (meth_str.sel == sel)
     {
        /* FIXME: hppa arch was doing a pointer dereference
           here.  There needs to be a better way to do that.  */
        fprintf( stderr, "%s match on %p\n", __PRETTY_FUNCTION__, (void *) meth_str.sel);
        return meth_str.imp;
     }
   }
   return( 0);
}


static CORE_ADDR
find_implementation_in_methodlist_array(struct gdbarch *gdbarch,
                                        CORE_ADDR methodlist_array,
                                        CORE_ADDR inheritance,
                                        CORE_ADDR sel)
{
   CORE_ADDR   mlistnum;
   CORE_ADDR   mlist;
   CORE_ADDR   found;


   // fprintf( stderr, "%s :: %p %p\n", __PRETTY_FUNCTION__, (void *) methodlist_array, (void *)sel);
   mlistnum = read_objc_pointerarray_count( gdbarch, methodlist_array);
         // fprintf( stderr, "%s :: mlistnum=%ld\n", __PRETTY_FUNCTION__, (long) mlistnum);
   if( ! mlistnum)  // can't happen
      return( 0);

   if( inheritance & MULLE_OBJC_CLASS_DONT_INHERIT_CATEGORIES)
       mlistnum = 1;

   // reverse enumerate
   while( mlistnum)
   {
     --mlistnum;
     mlist    = read_objc_pointerarray_entry( gdbarch, methodlist_array, mlistnum);
     // fprintf( stderr, "%s :: mlist=%p\n", __PRETTY_FUNCTION__, (void *) mlist);
     if (mlist == 0)
       break;

     found  = find_implementation_in_methodlist( gdbarch, mlist, sel);
     if( found)
        return( found);
   }
   return( 0);
}


// static struct _mulle_objc_method  *
//    _mulle_objc_class_protocol_search_method( struct _mulle_objc_class *cls,
//                                              struct _mulle_objc_searcharguments *search,
//                                              unsigned int inheritance,
//                                              struct _mulle_objc_searchresult *result,
//                                              enum internal_search_mode *mode)
// {
//    struct _mulle_objc_classpair                        *pair;
//    struct _mulle_objc_infraclass                       *infra;
//    struct _mulle_objc_class                            *walk_cls;
//    struct _mulle_objc_infraclass                       *proto_cls;
//    struct _mulle_objc_infraclass                       *next_proto_cls;
//    struct _mulle_objc_protocolclassreverseenumerator   rover;
//    struct _mulle_objc_method                           *found;
//    struct _mulle_objc_method                           *method;
//    int                                                 is_meta;
//
//    found        = MULLE_OBJC_METHOD_SEARCH_FAIL;
//    pair         = _mulle_objc_class_get_classpair( cls);
//    infra        = _mulle_objc_classpair_get_infraclass( pair);
//    is_meta      = _mulle_objc_class_is_metaclass( cls);
//    inheritance |= MULLE_OBJC_CLASS_DONT_INHERIT_SUPERCLASS;
//
//    rover          = _mulle_objc_classpair_reverseenumerate_protocolclasses( pair);
//    next_proto_cls = _mulle_objc_protocolclassreverseenumerator_next( &rover);
//    while( proto_cls = next_proto_cls)
//    {
//       next_proto_cls = _mulle_objc_protocolclassreverseenumerator_next( &rover);
//       if( proto_cls == infra)
//          continue;
//
//       walk_cls = _mulle_objc_infraclass_as_class( proto_cls);
//       if( is_meta)
//          walk_cls = _mulle_objc_metaclass_as_class( _mulle_objc_infraclass_get_metaclass( proto_cls));
//
//       method = __mulle_objc_class_search_method( walk_cls,
//                                                  search,
//                                                  inheritance | walk_cls->inheritance,
//                                                  result,
//                                                  mode);
//       if( method == MULLE_OBJC_METHOD_SEARCH_FAIL)
//          continue;
//
//       if( ! method)
//       {
//          found = NULL;
//          break;
//       }
//
//       if( found != MULLE_OBJC_METHOD_SEARCH_FAIL)
//       {
//          result->error = EEXIST;
//          found = NULL;
//          break;
//       }
//
//       found = method;
//
//       if( ! _mulle_objc_descriptor_is_hidden_override_fatal( &method->descriptor))
//          break;
//    }
//    _mulle_objc_protocolclassreverseenumerator_done( &rover);
//
//    return( found);
// }


static CORE_ADDR
find_implementation_from_class (struct gdbarch *gdbarch,
                                CORE_ADDR addr,
                                CORE_ADDR sel,
                                long inheritance,
                                long startClassid);

static CORE_ADDR
find_implementation_from_protocol_classes( struct gdbarch *gdbarch,
                                           CORE_ADDR addr,
                                           struct objc_class *p_class,
                                           CORE_ADDR sel,
                                           long inheritance,
                                           long startClassid)
{
   CORE_ADDR       found;
   CORE_ADDR       infraAddr;
   CORE_ADDR       metaAddr;
   CORE_ADDR       protocolclassesAddr;
   CORE_ADDR       protoclassAddr;
   unsigned long   i, n;
   int             is_meta;
   struct objc_class   class_str;

   // fprintf( stderr, "%s :: %p %p (%s)\n", __PRETTY_FUNCTION__, (void *) addr, (void *) sel, p_class->infra_class ? "is meta" : "is infra");

   if( p_class->infra_class)  // is meta
   {
      is_meta   = 1;
      infraAddr = p_class->infra_class;
      metaAddr  = addr;
   }
   else
   {
      is_meta   = 0;
      infraAddr = addr;
      metaAddr  = metaclass_of_infraclass( gdbarch, infraAddr);

      read_objc_class( gdbarch, metaAddr, &class_str);
      if( class_str.isa == 0)
         return( 0);
      p_class  = &class_str;
   }

   // offset
   protocolclassesAddr = protocolclass_array_of_metaclass( gdbarch, metaAddr);

   // storage

   // first entry after meta is then the protocol classes array
   // in class pair (nota reverse enumeration here)
   n = read_objc_pointerarray_count( gdbarch, protocolclassesAddr);
   for( i = n; i;)
   {
      --i;
      protoclassAddr = read_objc_pointerarray_entry( gdbarch, protocolclassesAddr, i);
      if( protoclassAddr == infraAddr)
         continue;

      if( ! protoclassAddr)
         break;

      if( is_meta)
         protoclassAddr = metaclass_of_infraclass( gdbarch, protoclassAddr);

      // just look through local list and don't walk
      found = find_implementation_from_class( gdbarch, protoclassAddr, sel, 0xFFFF, startClassid);
      if( found)
         return( found);
   }
   return( 0);
}


static CORE_ADDR
find_implementation_from_class (struct gdbarch *gdbarch,
			                       CORE_ADDR addr,
                                CORE_ADDR sel,
                                long inheritance,
                                long startClassid)
{
  CORE_ADDR classAddr;
  CORE_ADDR found;
  struct objc_class class_str;

  // fprintf( stderr, "%s :: %p %p\n", __PRETTY_FUNCTION__, (void *) addr, (void *)sel);

  classAddr = addr;
  while( classAddr != 0)
  {
      read_objc_class( gdbarch, classAddr, &class_str);
      if( class_str.isa == 0)
         return( 0);

      if( inheritance == -1)
         inheritance = class_str.inheritance;

      // ignore everthing until and including startClassid is found
      if( startClassid)
      {
         if( class_str.classid == startClassid)
            startClassid = 0;
      }
      else
      {
         found = find_implementation_in_methodlist_array( gdbarch, class_str.methods, inheritance, sel);
         if( found)
            return( found);
      }

      if( ! (inheritance & MULLE_OBJC_CLASS_DONT_INHERIT_PROTOCOLS))
      {
          CORE_ADDR  tmp;

          tmp = inheritance;
          if( inheritance & MULLE_OBJC_CLASS_DONT_INHERIT_PROTOCOL_CATEGORIES)
             tmp |= MULLE_OBJC_CLASS_DONT_INHERIT_CATEGORIES;

          found = find_implementation_from_protocol_classes( gdbarch,
                                                             classAddr,
                                                             &class_str,
                                                             sel,
                                                             tmp,
                                                             startClassid);
          if( found)
            return( found);
      }

      classAddr = search_superclass( gdbarch, classAddr, &class_str, inheritance);
      if( ! classAddr)
        return( 0);
  }

  return 0;
}


static CORE_ADDR
find_implementation (struct gdbarch *gdbarch,
          		      CORE_ADDR object, CORE_ADDR sel)
{
  struct objc_object ostr;

  // fprintf( stderr, "%s :: %p %p\n", __PRETTY_FUNCTION__, (void *) object, (void *)sel);
  if (object == 0)
    return 0;
  read_objc_object (gdbarch, object, &ostr);
  // fprintf( stderr, "%s :: isa=%p\n", __PRETTY_FUNCTION__, (void *) ostr.isa);
  if (ostr.isa == 0)
    return 0;

  return find_implementation_from_class (gdbarch, ostr.isa, sel, -1, 0);
}


#ifndef __cplusplus
CORE_ADDR
objc_find_implementation_from_class( struct gdbarch *gdbarch,
                                     CORE_ADDR classAddr,
                                     CORE_ADDR sel,
                                     long inheritance,
                                     long classid)
{
   return( find_implementation_from_class( gdbarch, classAddr, sel, inheritance, classid));
}
#else

// not part of the test

/* The data structure 'methcalls' is used to detect method calls (thru
 * ObjC runtime lib functions objc_msgSend, objc_msgSendSuper, etc.),
 * and ultimately find the method being called.
 */

struct objc_methcall {
  const char *name;
 /* Return instance method to be called.  */
  int (*stop_at) (CORE_ADDR, CORE_ADDR *);
  /* Start of pc range corresponding to method invocation.  */
  CORE_ADDR begin;
  /* End of pc range corresponding to method invocation.  */
  CORE_ADDR end;
};

static int resolve_msgsend (CORE_ADDR pc, CORE_ADDR *new_pc);
//static int resolve_msgsend_stret (CORE_ADDR pc, CORE_ADDR *new_pc);
static int resolve_msgsend_super (CORE_ADDR pc, CORE_ADDR *new_pc);
//static int resolve_msgsend_super_stret (CORE_ADDR pc, CORE_ADDR *new_pc);

static struct objc_methcall methcalls[] = {
//  { "_objc_msgSend", resolve_msgsend, 0, 0},
//  { "_objc_msgSend_stret", resolve_msgsend_stret, 0, 0},
//  { "_objc_msgSendSuper", resolve_msgsend_super, 0, 0},
//  { "_objc_msgSendSuper_stret", resolve_msgsend_super_stret, 0, 0},
//  { "_objc_getClass", NULL, 0, 0},
//  { "mulle_objc_object_call", resolve_msgsend, 0, 0},
  { "_mulle_objc_object_call", resolve_msgsend, 0, 0},
  { "_mulle_objc_object_supercall", resolve_msgsend_super, 0, 0},
  { "_mulle_objc_global_lookup_infraclass_nofail", NULL, 0, 0 }
//  { "_objc_getMetaClass", NULL, 0, 0}
};

#define nmethcalls (sizeof (methcalls) / sizeof (methcalls[0]))


/* The following function, "find_objc_msgsend", fills in the data
 * structure "objc_msgs" by finding the addresses of each of the
 * (currently four) functions that it holds (of which objc_msgSend is
 * the first).  This must be called each time symbols are loaded, in
 * case the functions have moved for some reason.
 */

static void
find_objc_msgsend (void)
{
  unsigned int i;

  for (i = 0; i < nmethcalls; i++)
    {
      struct bound_minimal_symbol func;

      /* Try both with and without underscore.  */
      func = lookup_bound_minimal_symbol (methcalls[i].name);
      if ((func.minsym == NULL) && (methcalls[i].name[0] == '_'))
   {
     func = lookup_bound_minimal_symbol (methcalls[i].name + 1);
   }
      if (func.minsym == NULL)
   {
          // fprintf( stderr, "%s :: did not find \"%s\"\n",
          //               __PRETTY_FUNCTION__, methcalls[i].name);
     methcalls[i].begin = 0;
     methcalls[i].end = 0;
     continue;
   }

      methcalls[i].begin = BMSYMBOL_VALUE_ADDRESS (func);
      methcalls[i].end = minimal_symbol_upper_bound (func);
      //fprintf( stderr, "%s :: found \"%s\" at %p-%p\n",
      //                  __PRETTY_FUNCTION__,
      //                  methcalls[i].name,
      //                  (void *) methcalls[i].begin,
      //                  (void *) methcalls[i].end);
    }
}


/* find_objc_msgcall (replaces pc_off_limits)
 *
 * ALL that this function now does is to determine whether the input
 * address ("pc") is the address of one of the Objective-C message
 * dispatch functions (mainly objc_msgSend or objc_msgSendSuper), and
 * if so, it returns the address of the method that will be called.
 *
 * The old function "pc_off_limits" used to do a lot of other things
 * in addition, such as detecting shared library jump stubs and
 * returning the address of the shlib function that would be called.
 * That functionality has been moved into the gdbarch_skip_trampoline_code and
 * IN_SOLIB_TRAMPOLINE macros, which are resolved in the target-
 * dependent modules.
 */

static int
find_objc_msgcall_submethod (int (*f) (CORE_ADDR, CORE_ADDR *),
              CORE_ADDR pc,
              CORE_ADDR *new_pc)
{
  try
    {
      if (f (pc, new_pc) == 0)
   return 1;
    }
  catch (const gdb_exception &ex)
    {
      exception_fprintf (gdb_stderr, ex,
          "Unable to determine target of "
          "Objective-C method call (ignoring):\n");
    }
  return 0;
}


int
find_objc_msgcall (CORE_ADDR pc, CORE_ADDR *new_pc)
{
  unsigned int i;

  find_objc_msgsend ();
  if (new_pc != NULL)
    {
      *new_pc = 0;
    }

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) pc);
  for (i = 0; i < nmethcalls; i++)
    if ((pc >= methcalls[i].begin) && (pc < methcalls[i].end))
      {
   if (methcalls[i].stop_at != NULL)
     return find_objc_msgcall_submethod (methcalls[i].stop_at,
                     pc, new_pc);
   else
     return 0;
      }

  return 0;
}



static int
resolve_msgsend (CORE_ADDR pc, CORE_ADDR *new_pc)
{
  struct frame_info *frame = get_current_frame ();
  struct gdbarch *gdbarch = get_frame_arch (frame);
  struct type *ptr_type = builtin_type (gdbarch)->builtin_data_ptr;

  CORE_ADDR object;
  CORE_ADDR sel;
  CORE_ADDR res;

  // fprintf( stderr, "%s :: %p (%p)\n", __PRETTY_FUNCTION__, (void *) pc, frame);

  object = gdbarch_fetch_pointer_argument (gdbarch, frame, 0, ptr_type);

  // fprintf( stderr, "%s ::object=%p\n", __PRETTY_FUNCTION__, (void *) object);

  sel = gdbarch_fetch_pointer_argument (gdbarch, frame, 1, ptr_type);

  // fprintf( stderr, "%s ::sel=%p\n", __PRETTY_FUNCTION__, (void *) sel);

  res = find_implementation (gdbarch, object, sel);
  if (new_pc != 0)
    *new_pc = res;
  if (res == 0)
    return 1;
  return 0;
}

//static int
//resolve_msgsend_stret (CORE_ADDR pc, CORE_ADDR *new_pc)
//{
//  struct frame_info *frame = get_current_frame ();
//  struct gdbarch *gdbarch = get_frame_arch (frame);
//  struct type *ptr_type = builtin_type (gdbarch)->builtin_func_ptr;
//
//  CORE_ADDR object;
//  CORE_ADDR sel;
//  CORE_ADDR res;
//
//  object = gdbarch_fetch_pointer_argument (gdbarch, frame, 1, ptr_type);
//  sel = gdbarch_fetch_pointer_argument (gdbarch, frame, 2, ptr_type);
//
//  res = find_implementation (gdbarch, object, sel);
//  if (new_pc != 0)
//    *new_pc = res;
//  if (res == 0)
//    return 1;
//  return 0;
//}

static int
resolve_msgsend_super (CORE_ADDR pc, CORE_ADDR *new_pc)
{
  struct frame_info *frame = get_current_frame ();
  struct gdbarch *gdbarch = get_frame_arch (frame);
  struct type *ptr_type = builtin_type (gdbarch)->builtin_data_ptr;
  struct objc_super  ssup;

  CORE_ADDR superid;

  // super is a little tricky, we need to lookup the class via
  // the universe...

//  object  = gdbarch_fetch_pointer_argument (gdbarch, frame, 0, ptr_type);
//  sel     = gdbarch_fetch_pointer_argument (gdbarch, frame, 1, ptr_type);
  // fprintf( stderr, "%s :: %p (%p)\n", __PRETTY_FUNCTION__, (void *) pc, frame);

  superid = gdbarch_fetch_pointer_argument (gdbarch, frame, 3, ptr_type);
  // fprintf( stderr, "%s :: superid=%p\n", __PRETTY_FUNCTION__, (void *) superid);
  if( ! superid)
     return( 0);

  CORE_ADDR universe;
  CORE_ADDR superTable;
  CORE_ADDR classTable;

  universe = read_universe();
  if( ! universe)
     return( 0);

  int   len;

  // fprintf( stderr, "%s :: %p\n", __PRETTY_FUNCTION__, (void *) addr);

  len = gdbarch_ptr_bit( gdbarch) / 8;

  //    _mulle_concurrent_hashmap_lookup
      // fprintf( stderr, "%s :: universe=%p\n", __PRETTY_FUNCTION__, (void *) universe);
      // now get to TPS table
  classTable  = universe;
  classTable += len; // skip cache
  classTable += 2 * len; // skip version + path

  superTable  = classTable;
  superTable += 4 * (3 * len); // skip 4 hashmaps

  CORE_ADDR superInfo;

  superInfo = search_hashtable( gdbarch, superTable, superid);
  if( ! superInfo)
     return( 0);

  read_objc_super( gdbarch, superInfo, &ssup);
  if( ssup.classid == 0 || ssup.methodid == 0)
    return 0;

  CORE_ADDR classAddr;

  classAddr = search_hashtable( gdbarch, classTable, ssup.classid);
  if( ! classAddr)
     return( 0);

  CORE_ADDR res;

  res = find_implementation_from_class( gdbarch, classAddr, ssup.methodid, -1, ssup.classid);
  if (new_pc != 0)
    *new_pc = res;
  if (res == 0)
    return 1;
  return 0;
}

//static int
//resolve_msgsend_super_stret (CORE_ADDR pc, CORE_ADDR *new_pc)
//{
//  struct frame_info *frame = get_current_frame ();
//  struct gdbarch *gdbarch = get_frame_arch (frame);
//  struct type *ptr_type = builtin_type (gdbarch)->builtin_func_ptr;
//
//  struct objc_super sstr;
//
//  CORE_ADDR super;
//  CORE_ADDR sel;
//  CORE_ADDR res;
//
//  super = gdbarch_fetch_pointer_argument (gdbarch, frame, 1, ptr_type);
//  sel = gdbarch_fetch_pointer_argument (gdbarch, frame, 2, ptr_type);
//
//  read_objc_super (gdbarch, super, &sstr);
//  if (sstr.theclass == 0)
//    return 0;
//
//  res = find_implementation_from_class (gdbarch, sstr.theclass, sel);
//  if (new_pc != 0)
//    *new_pc = res;
//  if (res == 0)
//    return 1;
//  return 0;
//}
#endif
