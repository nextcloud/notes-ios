#if 0
#elif defined(__arm64__) && __arm64__
// Generated by Apple Swift version 5.0 effective-4.1.50 (swiftlang-1001.0.69.5 clang-1001.0.46.3)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgcc-compat"

#if !defined(__has_include)
# define __has_include(x) 0
#endif
#if !defined(__has_attribute)
# define __has_attribute(x) 0
#endif
#if !defined(__has_feature)
# define __has_feature(x) 0
#endif
#if !defined(__has_warning)
# define __has_warning(x) 0
#endif

#if __has_include(<swift/objc-prologue.h>)
# include <swift/objc-prologue.h>
#endif

#pragma clang diagnostic ignored "-Wauto-import"
#include <Foundation/Foundation.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if !defined(SWIFT_TYPEDEFS)
# define SWIFT_TYPEDEFS 1
# if __has_include(<uchar.h>)
#  include <uchar.h>
# elif !defined(__cplusplus)
typedef uint_least16_t char16_t;
typedef uint_least32_t char32_t;
# endif
typedef float swift_float2  __attribute__((__ext_vector_type__(2)));
typedef float swift_float3  __attribute__((__ext_vector_type__(3)));
typedef float swift_float4  __attribute__((__ext_vector_type__(4)));
typedef double swift_double2  __attribute__((__ext_vector_type__(2)));
typedef double swift_double3  __attribute__((__ext_vector_type__(3)));
typedef double swift_double4  __attribute__((__ext_vector_type__(4)));
typedef int swift_int2  __attribute__((__ext_vector_type__(2)));
typedef int swift_int3  __attribute__((__ext_vector_type__(3)));
typedef int swift_int4  __attribute__((__ext_vector_type__(4)));
typedef unsigned int swift_uint2  __attribute__((__ext_vector_type__(2)));
typedef unsigned int swift_uint3  __attribute__((__ext_vector_type__(3)));
typedef unsigned int swift_uint4  __attribute__((__ext_vector_type__(4)));
#endif

#if !defined(SWIFT_PASTE)
# define SWIFT_PASTE_HELPER(x, y) x##y
# define SWIFT_PASTE(x, y) SWIFT_PASTE_HELPER(x, y)
#endif
#if !defined(SWIFT_METATYPE)
# define SWIFT_METATYPE(X) Class
#endif
#if !defined(SWIFT_CLASS_PROPERTY)
# if __has_feature(objc_class_property)
#  define SWIFT_CLASS_PROPERTY(...) __VA_ARGS__
# else
#  define SWIFT_CLASS_PROPERTY(...)
# endif
#endif

#if __has_attribute(objc_runtime_name)
# define SWIFT_RUNTIME_NAME(X) __attribute__((objc_runtime_name(X)))
#else
# define SWIFT_RUNTIME_NAME(X)
#endif
#if __has_attribute(swift_name)
# define SWIFT_COMPILE_NAME(X) __attribute__((swift_name(X)))
#else
# define SWIFT_COMPILE_NAME(X)
#endif
#if __has_attribute(objc_method_family)
# define SWIFT_METHOD_FAMILY(X) __attribute__((objc_method_family(X)))
#else
# define SWIFT_METHOD_FAMILY(X)
#endif
#if __has_attribute(noescape)
# define SWIFT_NOESCAPE __attribute__((noescape))
#else
# define SWIFT_NOESCAPE
#endif
#if __has_attribute(warn_unused_result)
# define SWIFT_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#else
# define SWIFT_WARN_UNUSED_RESULT
#endif
#if __has_attribute(noreturn)
# define SWIFT_NORETURN __attribute__((noreturn))
#else
# define SWIFT_NORETURN
#endif
#if !defined(SWIFT_CLASS_EXTRA)
# define SWIFT_CLASS_EXTRA
#endif
#if !defined(SWIFT_PROTOCOL_EXTRA)
# define SWIFT_PROTOCOL_EXTRA
#endif
#if !defined(SWIFT_ENUM_EXTRA)
# define SWIFT_ENUM_EXTRA
#endif
#if !defined(SWIFT_CLASS)
# if __has_attribute(objc_subclassing_restricted)
#  define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) __attribute__((objc_subclassing_restricted)) SWIFT_CLASS_EXTRA
#  define SWIFT_CLASS_NAMED(SWIFT_NAME) __attribute__((objc_subclassing_restricted)) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
# else
#  define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
#  define SWIFT_CLASS_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
# endif
#endif

#if !defined(SWIFT_PROTOCOL)
# define SWIFT_PROTOCOL(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_PROTOCOL_EXTRA
# define SWIFT_PROTOCOL_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_PROTOCOL_EXTRA
#endif

#if !defined(SWIFT_EXTENSION)
# define SWIFT_EXTENSION(M) SWIFT_PASTE(M##_Swift_, __LINE__)
#endif

#if !defined(OBJC_DESIGNATED_INITIALIZER)
# if __has_attribute(objc_designated_initializer)
#  define OBJC_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
# else
#  define OBJC_DESIGNATED_INITIALIZER
# endif
#endif
#if !defined(SWIFT_ENUM_ATTR)
# if defined(__has_attribute) && __has_attribute(enum_extensibility)
#  define SWIFT_ENUM_ATTR(_extensibility) __attribute__((enum_extensibility(_extensibility)))
# else
#  define SWIFT_ENUM_ATTR(_extensibility)
# endif
#endif
#if !defined(SWIFT_ENUM)
# define SWIFT_ENUM(_type, _name, _extensibility) enum _name : _type _name; enum SWIFT_ENUM_ATTR(_extensibility) SWIFT_ENUM_EXTRA _name : _type
# if __has_feature(generalized_swift_name)
#  define SWIFT_ENUM_NAMED(_type, _name, SWIFT_NAME, _extensibility) enum _name : _type _name SWIFT_COMPILE_NAME(SWIFT_NAME); enum SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_ENUM_ATTR(_extensibility) SWIFT_ENUM_EXTRA _name : _type
# else
#  define SWIFT_ENUM_NAMED(_type, _name, SWIFT_NAME, _extensibility) SWIFT_ENUM(_type, _name, _extensibility)
# endif
#endif
#if !defined(SWIFT_UNAVAILABLE)
# define SWIFT_UNAVAILABLE __attribute__((unavailable))
#endif
#if !defined(SWIFT_UNAVAILABLE_MSG)
# define SWIFT_UNAVAILABLE_MSG(msg) __attribute__((unavailable(msg)))
#endif
#if !defined(SWIFT_AVAILABILITY)
# define SWIFT_AVAILABILITY(plat, ...) __attribute__((availability(plat, __VA_ARGS__)))
#endif
#if !defined(SWIFT_DEPRECATED)
# define SWIFT_DEPRECATED __attribute__((deprecated))
#endif
#if !defined(SWIFT_DEPRECATED_MSG)
# define SWIFT_DEPRECATED_MSG(...) __attribute__((deprecated(__VA_ARGS__)))
#endif
#if __has_feature(attribute_diagnose_if_objc)
# define SWIFT_DEPRECATED_OBJC(Msg) __attribute__((diagnose_if(1, Msg, "warning")))
#else
# define SWIFT_DEPRECATED_OBJC(Msg) SWIFT_DEPRECATED_MSG(Msg)
#endif
#if __has_feature(modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import Foundation;
@import UIKit;
#endif

#pragma clang diagnostic ignored "-Wproperty-attribute-mismatch"
#pragma clang diagnostic ignored "-Wduplicate-method-arg"
#if __has_warning("-Wpragma-clang-attribute")
# pragma clang diagnostic ignored "-Wpragma-clang-attribute"
#endif
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wnullability"

#if __has_attribute(external_source_symbol)
# pragma push_macro("any")
# undef any
# pragma clang attribute push(__attribute__((external_source_symbol(language="Swift", defined_in="Marklight",generated_declaration))), apply_to=any(function,enum,objc_interface,objc_category,objc_protocol))
# pragma pop_macro("any")
#endif

@class NSCoder;
@class NSAttributedString;
@class NSDictionary;

/// <code>NSTextStorage</code> subclass that uses <code>Marklight</code> to highlight markdown syntax
/// on a <code>UITextView</code>.
/// In your <code>UIViewController</code> subclass keep a strong instance of the this
/// <code>MarklightTextStorage</code> class.
/// \code
/// let textStorage = MarklightTextStorage()
///
/// \endcodeCustomise the appearance as desired:
/// <ul>
///   <li>
///     Dynamic text style.
///   </li>
///   <li>
///     Markdown syntax color.
///   </li>
///   <li>
///     Code’s font and color.
///   </li>
///   <li>
///     Quotes’ font and color.
///   </li>
/// </ul>
/// As per Apple’s documentation it should be enough to assign the
/// <code>UITextView</code>’s <code>NSLayoutManager</code> to the <code>NSTextStorage</code> subclass, in our
/// case <code>MarklightTextStorage</code>.
/// \code
///  textStorage.addLayoutManager(textView.layoutManager)
///
/// \endcodeHowever I’m experiencing some crashes if I want to preload some text instead
/// of letting the user start from scratch with a new text. A workaround is
/// proposed below.
/// For simplicity we assume you have a <code>String</code> to be highlighted inside an
/// editable <code>UITextView</code> loaded from a storyboard.
/// \code
/// let string = "# My awesome markdown string"
///
/// \endcodeConvert <code>string</code> to an <code>NSAttributedString</code>
/// \code
/// let attributedString = NSAttributedString(string: string)
///
/// \endcodeSet the loaded string to the <code>UITextView</code>
/// \code
/// textView.attributedText = attributedString
///
/// \endcodeAppend the loaded string to the <code>NSTextStorage</code>
/// \code
/// textStorage.appendAttributedString(attributedString)
///
/// \endcodeFor more informations on how to implement your own <code>NSTextStorage</code> subclass,
/// follow Apple’s official documentation.
/// <ul>
///   <li>
///     see: <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorageDelegate_Protocol_TextKit/index.html#//apple_ref/swift/intf/c:objc(pl)NSTextStorage"><code>NSTextStorage</code></a>
///   </li>
///   <li>
///     see: <code>Marklight</code>
///   </li>
/// </ul>
SWIFT_CLASS("_TtC9Marklight20MarklightTextStorage")
@interface MarklightTextStorage : NSTextStorage
/// To customise the appearance of the markdown syntax highlights you should
/// subclass <code>MarklightTextProcessor</code>. Sends out
/// <code>-textStorage:willProcessEditing</code>, fixes the attributes, sends out
/// <code>-textStorage:didProcessEditing</code>, and notifies the layout managers of
/// change with the
/// <code>-processEditingForTextStorage:edited:range:changeInLength:invalidatedRange:</code>
/// method.  Invoked from <code>-edited:range:changeInLength:</code> or <code>-endEditing</code>.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
- (void)processEditing;
/// Use this method to extract the text from the <code>UITextView</code> as plain text.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
///
/// returns:
/// The <code>String</code> containing the text inside the <code>UITextView</code>.
@property (nonatomic, readonly, copy) NSString * _Nonnull string;
/// Returns the attributes for the character at a given index.
/// The attributes for the character at index.
/// \param index The index for which to return attributes. This value must
/// lie within the bounds of the receiver.
///
/// \param aRange Upon return, the range over which the attributes and
/// values are the same as those at index. This range isn’t necessarily the
/// maximum range covered, and its extent is implementation-dependent. If you
/// need the maximum range, use
/// attributesAtIndex:longestEffectiveRange:inRange:. If you don’t need this
/// value, pass NULL.
///
///
/// returns:
/// The attributes for the character at index.     - see:
/// <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
- (NSDictionary<NSAttributedStringKey, id> * _Nonnull)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer _Nullable)range SWIFT_WARN_UNUSED_RESULT;
/// Replaces the characters in the given range with the characters of the given
/// string. The new characters inherit the attributes of the first replaced
/// character from aRange. Where the length of aRange is 0, the new characters
/// inherit the attributes of the character preceding aRange if it has any,
/// otherwise of the character following aRange. Raises an NSRangeException if
/// any part of aRange lies beyond the end of the receiver’s characters.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
/// \param aRange A range specifying the characters to replace.
///
/// \param aString A string specifying the characters to replace those in
/// aRange.
///
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString * _Nonnull)str;
/// Sets the attributes for the characters in the specified range to the
/// specified attributes. These new attributes replace any attributes previously
/// associated with the characters in aRange. Raises an NSRangeException if any
/// part of aRange lies beyond the end of the receiver’s characters. To set
/// attributes for a zero-length NSMutableAttributedString displayed in a text
/// view, use the NSTextView method setTypingAttributes:.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSMutableAttributedString_Class/index.html#//apple_ref/swift/cl/c:objc(cs)NSMutableAttributedString"><code>NSMutableAttributedString</code></a>
///   </li>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
/// \param attributes A dictionary containing the attributes to set.
/// Attribute keys can be supplied by another framework or can be custom ones
/// you define. For information about where to find the system-supplied
/// attribute keys, see the overview section in NSAttributedString Class
/// Reference.
///
/// \param aRange The range of characters whose attributes are set.
///
- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> * _Nullable)attrs range:(NSRange)range;
- (nonnull instancetype)init OBJC_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder * _Nonnull)aDecoder OBJC_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithString:(NSString * _Nonnull)str SWIFT_UNAVAILABLE;
- (nonnull instancetype)initWithString:(NSString * _Nonnull)str attributes:(NSDictionary<NSAttributedStringKey, id> * _Nullable)attrs SWIFT_UNAVAILABLE;
- (nonnull instancetype)initWithAttributedString:(NSAttributedString * _Nonnull)attrStr SWIFT_UNAVAILABLE;
- (nullable instancetype)initWithURL:(NSURL * _Nonnull)url options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> * _Nonnull)options documentAttributes:(NSDictionary * _Nullable * _Nullable)dict error:(NSError * _Nullable * _Nullable)error SWIFT_UNAVAILABLE;
- (nullable instancetype)initWithData:(NSData * _Nonnull)data options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> * _Nonnull)options documentAttributes:(NSDictionary * _Nullable * _Nullable)dict error:(NSError * _Nullable * _Nullable)error SWIFT_UNAVAILABLE;
- (nullable instancetype)initWithFileURL:(NSURL * _Nonnull)url options:(NSDictionary * _Nonnull)options documentAttributes:(NSDictionary * _Nullable * _Nullable)dict error:(NSError * _Nullable * _Nullable)error SWIFT_UNAVAILABLE;
@end





#if __has_attribute(external_source_symbol)
# pragma clang attribute pop
#endif
#pragma clang diagnostic pop

#elif defined(__ARM_ARCH_7A__) && __ARM_ARCH_7A__
// Generated by Apple Swift version 5.0 effective-4.1.50 (swiftlang-1001.0.69.5 clang-1001.0.46.3)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgcc-compat"

#if !defined(__has_include)
# define __has_include(x) 0
#endif
#if !defined(__has_attribute)
# define __has_attribute(x) 0
#endif
#if !defined(__has_feature)
# define __has_feature(x) 0
#endif
#if !defined(__has_warning)
# define __has_warning(x) 0
#endif

#if __has_include(<swift/objc-prologue.h>)
# include <swift/objc-prologue.h>
#endif

#pragma clang diagnostic ignored "-Wauto-import"
#include <Foundation/Foundation.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#if !defined(SWIFT_TYPEDEFS)
# define SWIFT_TYPEDEFS 1
# if __has_include(<uchar.h>)
#  include <uchar.h>
# elif !defined(__cplusplus)
typedef uint_least16_t char16_t;
typedef uint_least32_t char32_t;
# endif
typedef float swift_float2  __attribute__((__ext_vector_type__(2)));
typedef float swift_float3  __attribute__((__ext_vector_type__(3)));
typedef float swift_float4  __attribute__((__ext_vector_type__(4)));
typedef double swift_double2  __attribute__((__ext_vector_type__(2)));
typedef double swift_double3  __attribute__((__ext_vector_type__(3)));
typedef double swift_double4  __attribute__((__ext_vector_type__(4)));
typedef int swift_int2  __attribute__((__ext_vector_type__(2)));
typedef int swift_int3  __attribute__((__ext_vector_type__(3)));
typedef int swift_int4  __attribute__((__ext_vector_type__(4)));
typedef unsigned int swift_uint2  __attribute__((__ext_vector_type__(2)));
typedef unsigned int swift_uint3  __attribute__((__ext_vector_type__(3)));
typedef unsigned int swift_uint4  __attribute__((__ext_vector_type__(4)));
#endif

#if !defined(SWIFT_PASTE)
# define SWIFT_PASTE_HELPER(x, y) x##y
# define SWIFT_PASTE(x, y) SWIFT_PASTE_HELPER(x, y)
#endif
#if !defined(SWIFT_METATYPE)
# define SWIFT_METATYPE(X) Class
#endif
#if !defined(SWIFT_CLASS_PROPERTY)
# if __has_feature(objc_class_property)
#  define SWIFT_CLASS_PROPERTY(...) __VA_ARGS__
# else
#  define SWIFT_CLASS_PROPERTY(...)
# endif
#endif

#if __has_attribute(objc_runtime_name)
# define SWIFT_RUNTIME_NAME(X) __attribute__((objc_runtime_name(X)))
#else
# define SWIFT_RUNTIME_NAME(X)
#endif
#if __has_attribute(swift_name)
# define SWIFT_COMPILE_NAME(X) __attribute__((swift_name(X)))
#else
# define SWIFT_COMPILE_NAME(X)
#endif
#if __has_attribute(objc_method_family)
# define SWIFT_METHOD_FAMILY(X) __attribute__((objc_method_family(X)))
#else
# define SWIFT_METHOD_FAMILY(X)
#endif
#if __has_attribute(noescape)
# define SWIFT_NOESCAPE __attribute__((noescape))
#else
# define SWIFT_NOESCAPE
#endif
#if __has_attribute(warn_unused_result)
# define SWIFT_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#else
# define SWIFT_WARN_UNUSED_RESULT
#endif
#if __has_attribute(noreturn)
# define SWIFT_NORETURN __attribute__((noreturn))
#else
# define SWIFT_NORETURN
#endif
#if !defined(SWIFT_CLASS_EXTRA)
# define SWIFT_CLASS_EXTRA
#endif
#if !defined(SWIFT_PROTOCOL_EXTRA)
# define SWIFT_PROTOCOL_EXTRA
#endif
#if !defined(SWIFT_ENUM_EXTRA)
# define SWIFT_ENUM_EXTRA
#endif
#if !defined(SWIFT_CLASS)
# if __has_attribute(objc_subclassing_restricted)
#  define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) __attribute__((objc_subclassing_restricted)) SWIFT_CLASS_EXTRA
#  define SWIFT_CLASS_NAMED(SWIFT_NAME) __attribute__((objc_subclassing_restricted)) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
# else
#  define SWIFT_CLASS(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
#  define SWIFT_CLASS_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_CLASS_EXTRA
# endif
#endif

#if !defined(SWIFT_PROTOCOL)
# define SWIFT_PROTOCOL(SWIFT_NAME) SWIFT_RUNTIME_NAME(SWIFT_NAME) SWIFT_PROTOCOL_EXTRA
# define SWIFT_PROTOCOL_NAMED(SWIFT_NAME) SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_PROTOCOL_EXTRA
#endif

#if !defined(SWIFT_EXTENSION)
# define SWIFT_EXTENSION(M) SWIFT_PASTE(M##_Swift_, __LINE__)
#endif

#if !defined(OBJC_DESIGNATED_INITIALIZER)
# if __has_attribute(objc_designated_initializer)
#  define OBJC_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
# else
#  define OBJC_DESIGNATED_INITIALIZER
# endif
#endif
#if !defined(SWIFT_ENUM_ATTR)
# if defined(__has_attribute) && __has_attribute(enum_extensibility)
#  define SWIFT_ENUM_ATTR(_extensibility) __attribute__((enum_extensibility(_extensibility)))
# else
#  define SWIFT_ENUM_ATTR(_extensibility)
# endif
#endif
#if !defined(SWIFT_ENUM)
# define SWIFT_ENUM(_type, _name, _extensibility) enum _name : _type _name; enum SWIFT_ENUM_ATTR(_extensibility) SWIFT_ENUM_EXTRA _name : _type
# if __has_feature(generalized_swift_name)
#  define SWIFT_ENUM_NAMED(_type, _name, SWIFT_NAME, _extensibility) enum _name : _type _name SWIFT_COMPILE_NAME(SWIFT_NAME); enum SWIFT_COMPILE_NAME(SWIFT_NAME) SWIFT_ENUM_ATTR(_extensibility) SWIFT_ENUM_EXTRA _name : _type
# else
#  define SWIFT_ENUM_NAMED(_type, _name, SWIFT_NAME, _extensibility) SWIFT_ENUM(_type, _name, _extensibility)
# endif
#endif
#if !defined(SWIFT_UNAVAILABLE)
# define SWIFT_UNAVAILABLE __attribute__((unavailable))
#endif
#if !defined(SWIFT_UNAVAILABLE_MSG)
# define SWIFT_UNAVAILABLE_MSG(msg) __attribute__((unavailable(msg)))
#endif
#if !defined(SWIFT_AVAILABILITY)
# define SWIFT_AVAILABILITY(plat, ...) __attribute__((availability(plat, __VA_ARGS__)))
#endif
#if !defined(SWIFT_DEPRECATED)
# define SWIFT_DEPRECATED __attribute__((deprecated))
#endif
#if !defined(SWIFT_DEPRECATED_MSG)
# define SWIFT_DEPRECATED_MSG(...) __attribute__((deprecated(__VA_ARGS__)))
#endif
#if __has_feature(attribute_diagnose_if_objc)
# define SWIFT_DEPRECATED_OBJC(Msg) __attribute__((diagnose_if(1, Msg, "warning")))
#else
# define SWIFT_DEPRECATED_OBJC(Msg) SWIFT_DEPRECATED_MSG(Msg)
#endif
#if __has_feature(modules)
#if __has_warning("-Watimport-in-framework-header")
#pragma clang diagnostic ignored "-Watimport-in-framework-header"
#endif
@import Foundation;
@import UIKit;
#endif

#pragma clang diagnostic ignored "-Wproperty-attribute-mismatch"
#pragma clang diagnostic ignored "-Wduplicate-method-arg"
#if __has_warning("-Wpragma-clang-attribute")
# pragma clang diagnostic ignored "-Wpragma-clang-attribute"
#endif
#pragma clang diagnostic ignored "-Wunknown-pragmas"
#pragma clang diagnostic ignored "-Wnullability"

#if __has_attribute(external_source_symbol)
# pragma push_macro("any")
# undef any
# pragma clang attribute push(__attribute__((external_source_symbol(language="Swift", defined_in="Marklight",generated_declaration))), apply_to=any(function,enum,objc_interface,objc_category,objc_protocol))
# pragma pop_macro("any")
#endif

@class NSCoder;
@class NSAttributedString;
@class NSDictionary;

/// <code>NSTextStorage</code> subclass that uses <code>Marklight</code> to highlight markdown syntax
/// on a <code>UITextView</code>.
/// In your <code>UIViewController</code> subclass keep a strong instance of the this
/// <code>MarklightTextStorage</code> class.
/// \code
/// let textStorage = MarklightTextStorage()
///
/// \endcodeCustomise the appearance as desired:
/// <ul>
///   <li>
///     Dynamic text style.
///   </li>
///   <li>
///     Markdown syntax color.
///   </li>
///   <li>
///     Code’s font and color.
///   </li>
///   <li>
///     Quotes’ font and color.
///   </li>
/// </ul>
/// As per Apple’s documentation it should be enough to assign the
/// <code>UITextView</code>’s <code>NSLayoutManager</code> to the <code>NSTextStorage</code> subclass, in our
/// case <code>MarklightTextStorage</code>.
/// \code
///  textStorage.addLayoutManager(textView.layoutManager)
///
/// \endcodeHowever I’m experiencing some crashes if I want to preload some text instead
/// of letting the user start from scratch with a new text. A workaround is
/// proposed below.
/// For simplicity we assume you have a <code>String</code> to be highlighted inside an
/// editable <code>UITextView</code> loaded from a storyboard.
/// \code
/// let string = "# My awesome markdown string"
///
/// \endcodeConvert <code>string</code> to an <code>NSAttributedString</code>
/// \code
/// let attributedString = NSAttributedString(string: string)
///
/// \endcodeSet the loaded string to the <code>UITextView</code>
/// \code
/// textView.attributedText = attributedString
///
/// \endcodeAppend the loaded string to the <code>NSTextStorage</code>
/// \code
/// textStorage.appendAttributedString(attributedString)
///
/// \endcodeFor more informations on how to implement your own <code>NSTextStorage</code> subclass,
/// follow Apple’s official documentation.
/// <ul>
///   <li>
///     see: <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorageDelegate_Protocol_TextKit/index.html#//apple_ref/swift/intf/c:objc(pl)NSTextStorage"><code>NSTextStorage</code></a>
///   </li>
///   <li>
///     see: <code>Marklight</code>
///   </li>
/// </ul>
SWIFT_CLASS("_TtC9Marklight20MarklightTextStorage")
@interface MarklightTextStorage : NSTextStorage
/// To customise the appearance of the markdown syntax highlights you should
/// subclass <code>MarklightTextProcessor</code>. Sends out
/// <code>-textStorage:willProcessEditing</code>, fixes the attributes, sends out
/// <code>-textStorage:didProcessEditing</code>, and notifies the layout managers of
/// change with the
/// <code>-processEditingForTextStorage:edited:range:changeInLength:invalidatedRange:</code>
/// method.  Invoked from <code>-edited:range:changeInLength:</code> or <code>-endEditing</code>.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
- (void)processEditing;
/// Use this method to extract the text from the <code>UITextView</code> as plain text.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
///
/// returns:
/// The <code>String</code> containing the text inside the <code>UITextView</code>.
@property (nonatomic, readonly, copy) NSString * _Nonnull string;
/// Returns the attributes for the character at a given index.
/// The attributes for the character at index.
/// \param index The index for which to return attributes. This value must
/// lie within the bounds of the receiver.
///
/// \param aRange Upon return, the range over which the attributes and
/// values are the same as those at index. This range isn’t necessarily the
/// maximum range covered, and its extent is implementation-dependent. If you
/// need the maximum range, use
/// attributesAtIndex:longestEffectiveRange:inRange:. If you don’t need this
/// value, pass NULL.
///
///
/// returns:
/// The attributes for the character at index.     - see:
/// <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
- (NSDictionary<NSAttributedStringKey, id> * _Nonnull)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer _Nullable)range SWIFT_WARN_UNUSED_RESULT;
/// Replaces the characters in the given range with the characters of the given
/// string. The new characters inherit the attributes of the first replaced
/// character from aRange. Where the length of aRange is 0, the new characters
/// inherit the attributes of the character preceding aRange if it has any,
/// otherwise of the character following aRange. Raises an NSRangeException if
/// any part of aRange lies beyond the end of the receiver’s characters.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
/// \param aRange A range specifying the characters to replace.
///
/// \param aString A string specifying the characters to replace those in
/// aRange.
///
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString * _Nonnull)str;
/// Sets the attributes for the characters in the specified range to the
/// specified attributes. These new attributes replace any attributes previously
/// associated with the characters in aRange. Raises an NSRangeException if any
/// part of aRange lies beyond the end of the receiver’s characters. To set
/// attributes for a zero-length NSMutableAttributedString displayed in a text
/// view, use the NSTextView method setTypingAttributes:.
/// <ul>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Classes/NSMutableAttributedString_Class/index.html#//apple_ref/swift/cl/c:objc(cs)NSMutableAttributedString"><code>NSMutableAttributedString</code></a>
///   </li>
///   <li>
///     see:
///     <a href="xcdoc://?url=developer.apple.com/library/ios/documentation/UIKit/Reference/NSTextStorage_Class_TextKit/index.html#//apple_ref/doc/uid/TP40013282"><code>NSTextStorage</code></a>
///   </li>
/// </ul>
/// \param attributes A dictionary containing the attributes to set.
/// Attribute keys can be supplied by another framework or can be custom ones
/// you define. For information about where to find the system-supplied
/// attribute keys, see the overview section in NSAttributedString Class
/// Reference.
///
/// \param aRange The range of characters whose attributes are set.
///
- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> * _Nullable)attrs range:(NSRange)range;
- (nonnull instancetype)init OBJC_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder * _Nonnull)aDecoder OBJC_DESIGNATED_INITIALIZER;
- (nonnull instancetype)initWithString:(NSString * _Nonnull)str SWIFT_UNAVAILABLE;
- (nonnull instancetype)initWithString:(NSString * _Nonnull)str attributes:(NSDictionary<NSAttributedStringKey, id> * _Nullable)attrs SWIFT_UNAVAILABLE;
- (nonnull instancetype)initWithAttributedString:(NSAttributedString * _Nonnull)attrStr SWIFT_UNAVAILABLE;
- (nullable instancetype)initWithURL:(NSURL * _Nonnull)url options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> * _Nonnull)options documentAttributes:(NSDictionary * _Nullable * _Nullable)dict error:(NSError * _Nullable * _Nullable)error SWIFT_UNAVAILABLE;
- (nullable instancetype)initWithData:(NSData * _Nonnull)data options:(NSDictionary<NSAttributedStringDocumentReadingOptionKey, id> * _Nonnull)options documentAttributes:(NSDictionary * _Nullable * _Nullable)dict error:(NSError * _Nullable * _Nullable)error SWIFT_UNAVAILABLE;
- (nullable instancetype)initWithFileURL:(NSURL * _Nonnull)url options:(NSDictionary * _Nonnull)options documentAttributes:(NSDictionary * _Nullable * _Nullable)dict error:(NSError * _Nullable * _Nullable)error SWIFT_UNAVAILABLE;
@end





#if __has_attribute(external_source_symbol)
# pragma clang attribute pop
#endif
#pragma clang diagnostic pop

#endif
