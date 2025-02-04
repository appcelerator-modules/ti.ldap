/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2012 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiLdapSearchRequestProxy.h"
#import "TiLdapSearchResultProxy.h"
#import "TiUtils.h"

@implementation TiLdapSearchRequestProxy

+(id)requestWithProxy:(TiLdapConnectionProxy*)connection
{
    return [[[self alloc] initRequest:@"search" connection:connection] autorelease];
}

// Override and create search result proxy
-(void)handleSuccess:(id)result
{
    // Create a search result proxy to be returned in the callback
    TiLdapSearchResultProxy *searchResultProxy = [TiLdapSearchResultProxy searchResultWithLDAPMessage:_ldapMessage connection:_connection];

    // NOTE: Since the search result proxy is taking ownership of the _ldapMessage we need to
    // reset the pointer to null after creating the proxy so that the request proxy cleanup
    // logic does not free the _ldapMessage.
    _ldapMessage = NULL;
    
    [super handleSuccess:searchResultProxy];
}

-(int)execute:(NSDictionary*)args async:(BOOL)async
{
    if (![self isConnectionBound]) {
        return -1;
    }
    
    NSString *base = [TiUtils stringValue:@"base" properties:args def:@""];
    int scope = [TiUtils intValue:@"scope" properties:args def:LDAP_SCOPE_DEFAULT];
    
	// Use the same default value that openLDAP uses when a filter is not provided
    NSString *filter = @"(objectClass=*)";
    id inFilter = [args objectForKey:@"filter"];
    if (!IS_NULL_OR_NIL(inFilter)) {
        filter = [TiUtils stringValue:inFilter];
    }

    // Attributes are passed as an array of strings. Convert to an array of UTF8 strings.
    const char** attrs = NULL;
    id inAttrs = [args objectForKey:@"attrs"];
    ENSURE_TYPE_OR_NIL(inAttrs,NSArray);
    int count = [inAttrs count];
    if (count > 0) {
        attrs = malloc(sizeof(const char*) * (count+1));
        if (attrs) {
            for (int i=0; i<count; i++) {
                attrs[i] = [[inAttrs objectAtIndex:i] UTF8String];
            }
            // Null terminate the array
            attrs[count] = NULL;
        }
    }
    
    BOOL attrsOnly = [TiUtils boolValue:@"attrsOnly" properties:args def:0];
    int sizeLimit = [TiUtils intValue:@"sizeLimit" properties:args def:0];
    id timeLimit = [args objectForKey:@"timeLimit"]; // ms
    // Negative values indicate no timeLimit is desired
    struct timeval timeVal = { -1, -1 };
    if (!IS_NULL_OR_NIL(timeLimit)) {
        int value = [TiUtils intValue:timeLimit];
        timeVal.tv_sec = value;
        timeVal.tv_usec = 0;
    }
    
    int result;
    if (async) {
        result = ldap_search_ext(_connection.ld,
                                 [base UTF8String],
                                 scope,
                                 [filter UTF8String],
                                 (char**)attrs,
                                 attrsOnly,
                                 NULL,
                                 NULL,
                                 &timeVal,
                                 sizeLimit,
                                 &_messageId);
        // Get the last result code
        ldap_get_option(_connection.ld, LDAP_OPT_RESULT_CODE, &result);
    } else {
        result = ldap_search_ext_s(_connection.ld,
                                   [base UTF8String],
                                   scope,
                                   [filter UTF8String],
                                   (char**)attrs,
                                   attrsOnly,
                                   NULL,
                                   NULL,
                                   &timeVal,
                                   sizeLimit,
                                   &_ldapMessage);
    }
    
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    return result;
}

@end
