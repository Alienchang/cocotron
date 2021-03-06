/* Copyright (c) 2006-2007 Christopher J. W. Lloyd
                 2009 Markus Hitter <mah@jump-ing.de>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <Foundation/NSFileManager_win32.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSString_cString.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSThread-Private.h>

#import <Foundation/NSPlatform_win32.h>
#import <Foundation/NSString_win32.h>

#import <windows.h>

@implementation NSFileManager(windows)

+allocWithZone:(NSZone *)zone {
   return NSAllocateObject([NSFileManager_win32 class],0,NULL);
}

@end

@implementation NSFileManager_win32

-(BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data 
             attributes:(NSDictionary *)attributes {
   return [[NSPlatform currentPlatform] writeContentsOfFile:path bytes:[data bytes] length:[data length] atomically:YES];
}

-(NSArray *)directoryContentsAtPath:(NSString *)path {
   NSMutableArray *result=[NSMutableArray array];
   WIN32_FIND_DATAW findData;
   HANDLE          handle=FindFirstFileW([[path stringByAppendingString:@"\\*.*"] fileSystemRepresentationW],&findData);

   if(handle==INVALID_HANDLE_VALUE)
    return nil;

   do{
    if(wcscmp(findData.cFileName,L".")!=0 && wcscmp(findData.cFileName,L"..")!=0)
     [result addObject:[NSString stringWithCharacters:findData.cFileName length:wcslen(findData.cFileName)]];
   }while(FindNextFileW(handle,&findData));

   FindClose(handle);

   return result;
}

-(BOOL)createDirectoryAtPath:(NSString *)path
                  attributes:(NSDictionary *)attributes {
   return CreateDirectoryW([path fileSystemRepresentationW],NULL)?YES:NO;
}

-(BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
   DWORD attributes=GetFileAttributesW([path fileSystemRepresentationW]);

   if(attributes==0xFFFFFFFF)
    return NO;

   if(isDirectory!=NULL)
    *isDirectory=(attributes&FILE_ATTRIBUTE_DIRECTORY)?YES:NO;

   return YES;
#if 0
   struct stat buf;

   *isDirectory=NO;

   if(stat([path fileSystemRepresentationW],&buf)<0)
    return NO;

   if((buf.st_mode&S_IFMT)==S_IFDIR)
    *isDirectory=YES;

   return YES;
#endif
}


// we dont want to use fileExists... because it chases links 
-(BOOL)_isDirectory:(NSString *)path {
   DWORD attributes=GetFileAttributesW([path fileSystemRepresentationW]);

   if(attributes==0xFFFFFFFF)
    return NO;

   return (attributes&FILE_ATTRIBUTE_DIRECTORY)?YES:NO;
}

-(BOOL)removeFileAtPath:(NSString *)path handler:handler {
   const unichar *fsrep=[path fileSystemRepresentationW];
   DWORD       attribute=GetFileAttributesW(fsrep);

   if([path isEqualToString:@"."] || [path isEqualToString:@".."])
    [NSException raise:NSInvalidArgumentException format:@"-[%@ %s] path should not be . or ..",isa,sel_getName(_cmd)];

   if(attribute==0xFFFFFFFF)
    return NO;

   if(attribute&FILE_ATTRIBUTE_READONLY){
    attribute&=~FILE_ATTRIBUTE_READONLY;
    if(!SetFileAttributesW(fsrep,attribute))
     return NO;
   }

   if(![self _isDirectory:path]){
    if(!DeleteFileW(fsrep))
     return NO;
   }
   else {
    NSArray *contents=[self directoryContentsAtPath:path];
    NSInteger      i,count=[contents count];

    for(i=0;i<count;i++){
     NSString *fullPath=[path stringByAppendingPathComponent:[contents objectAtIndex:i]];
     if(![self removeFileAtPath:fullPath handler:handler])
      return NO;
    }

    if(!RemoveDirectoryW(fsrep))
     return NO;
   }
   return YES;
}

-(BOOL)movePath:(NSString *)src toPath:(NSString *)dest handler:handler {
   return MoveFileW([src fileSystemRepresentationW],[dest fileSystemRepresentationW])?YES:NO;
}

-(BOOL)copyPath:(NSString *)src toPath:(NSString *)dest handler:handler {
   BOOL isDirectory;

   if(![self fileExistsAtPath:src isDirectory:&isDirectory])
    return NO;

   if(!isDirectory){
    if(!CopyFileW([src fileSystemRepresentationW],[dest fileSystemRepresentationW],YES))
     return NO;
   }
   else {
    NSArray *files=[self directoryContentsAtPath:src];
    NSInteger      i,count=[files count];

    if(!CreateDirectoryW([dest fileSystemRepresentationW],NULL))
     return NO;

    for(i=0;i<count;i++){
     NSString *name=[files objectAtIndex:i];
     NSString *subsrc=[src stringByAppendingPathComponent:name];
     NSString *subdst=[dest stringByAppendingPathComponent:name];

     if(![self copyPath:subsrc toPath:subdst handler:handler])
      return NO;
    }

   }

   return YES;
}

-(NSDictionary *)fileAttributesAtPath:(NSString *)path traverseLink:(BOOL)traverse {
   NSMutableDictionary       *result=[NSMutableDictionary dictionary];
   WIN32_FILE_ATTRIBUTE_DATA  fileData;
   NSDate                    *date;

   if(!GetFileAttributesExW([path fileSystemRepresentationW],GetFileExInfoStandard,&fileData))
    return nil;

   date=[NSDate dateWithTimeIntervalSinceReferenceDate:Win32TimeIntervalFromFileTime(fileData.ftLastWriteTime)];
   [result setObject:date forKey:NSFileModificationDate];

   // dth
   NSString* fileType = NSFileTypeRegular;
   if (fileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
          fileType = NSFileTypeDirectory;
   // FIX: Support for links and other attributes needed!

   [result setObject:fileType forKey:NSFileType];
   [result setObject:@"USER" forKey:NSFileOwnerAccountName];
   [result setObject:@"GROUP" forKey:NSFileGroupOwnerAccountName];
   [result setObject:[NSNumber numberWithUnsignedLong:0666]
              forKey:NSFilePosixPermissions];
	uint64_t sizeOfFile = fileData.nFileSizeLow;
	uint64_t sizeHigh = fileData.nFileSizeHigh;
	sizeOfFile |= sizeHigh << 32;
	
	[result setObject:[NSNumber numberWithUnsignedLongLong:sizeOfFile]
			   forKey:NSFileSize];	

   return result;
}

-(BOOL)isReadableFileAtPath:(NSString *)path {
   DWORD attributes=GetFileAttributesW([path fileSystemRepresentationW]);

   if(attributes==-1)
    return NO;

   if(attributes&FILE_ATTRIBUTE_DIRECTORY)
    return NO;

   return YES;
}

-(BOOL)isWritableFileAtPath:(NSString *)path {
   DWORD attributes=GetFileAttributesW([path fileSystemRepresentationW]);

   if(attributes==-1)
    return NO;

   if(attributes&(FILE_ATTRIBUTE_DIRECTORY|FILE_ATTRIBUTE_READONLY))
    return NO;

   return YES;
}

-(BOOL)isExecutableFileAtPath:(NSString *)path {
   DWORD attributes=GetFileAttributesW([path fileSystemRepresentationW]);

   if(attributes==-1)
    return NO;

   if(attributes&(FILE_ATTRIBUTE_DIRECTORY))
    return NO;

   return [[[path pathExtension] uppercaseString] isEqualToString:@"EXE"];
}

-(BOOL)changeFileAttributes:(NSDictionary *)attributes atPath:(NSString *)path {
   NSUnimplementedMethod();
   return NO;
#if 0
   NSDate *date=[attributes objectForKey:NSFileModificationDate];

   if(date!=nil){
    time_t timep[2]={ time(NULL),[date timeIntervalSince1970] };
    if(utime((unichar *)[path fileSystemRepresentationW],timep)<0)
     return NO;
   }
   return YES;
#endif
}

-(NSString *)currentDirectoryPath {
   unichar  path[MAX_PATH+1];
   DWORD length;

   length=GetCurrentDirectoryW(MAX_PATH+1,path);
   Win32Assert("GetCurrentDirectory");

   return [NSString stringWithCharacters:path length:length];
}

-(BOOL)changeCurrentDirectoryPath:(NSString *)path {

   if (SetCurrentDirectoryW([self fileSystemRepresentationWithPathW:path]))
    return YES;
   Win32Assert("SetCurrentDirectory");

   return NO;
}


-(const unichar*)fileSystemRepresentationWithPathW:(NSString *)path {
   NSUInteger i,length=[path length];
   unichar  buffer[length];
   BOOL     converted=NO;

   [path getCharacters:buffer];

   for(i=0;i<length;i++){
    if(buffer[i]=='/'){
     buffer[i]='\\';
     converted=YES;
    }
   }

   if(converted){
    //NSLog(@"%s %@",sel_getName(_cmd),path);
    path=[NSString stringWithCharacters:buffer length:length];
   }

   return (const unichar *)[path cStringUsingEncoding:NSUnicodeStringEncoding];
}

-(const char*)fileSystemRepresentationWithPath:(NSString *)path {
	NSUInteger i,length=[path length];
	char  buffer[length];
	BOOL     converted=NO;
	
	[path getCString:buffer];
	
	for(i=0;i<length;i++){
		if(buffer[i]=='/'){
			buffer[i]='\\';
			converted=YES;
		}
	}
	
	if(converted){
		//NSLog(@"%s %@",sel_getName(_cmd),path);
		path=[NSString stringWithCString:buffer length:length];
	}
	//	NSLog(path);
   return [path cString];
}



@end
