/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - David Young <daver@geeks.org>
#import <Foundation/NSTask_posix.h>
#import <Foundation/NSRunLoop-InputSource.h>
#import <Foundation/NSPlatform_posix.h>
#import <Foundation/NSFileHandle_posix.h>
#import <Foundation/Foundation.h>

#include <unistd.h>
#include <sys/ioctl.h>
#include <signal.h>
#include <errno.h>

// these cannot be static, subclasses need them :/
NSMutableArray *_liveTasks = nil;
NSPipe *_taskPipe = nil;

@implementation NSTask_posix

void childSignalHandler(int sig);

// it is possible that this code could execute before _taskPipe is set up, in
// which case we wind up send some messages to nil.
void childSignalHandler(int sig) {
    if (sig == SIGCHLD) {
// FIX, this probably isnt safe to do from a signal handler
       uint32_t quad = 32;
       NSData *data = [NSData dataWithBytes:&quad length:sizeof(uint32_t)];
       NSFileHandle *handle = [_taskPipe fileHandleForWriting];

       [handle writeData:data];
    }
}

+(void)signalPipeReadNotification:(NSNotification *)note {
   [[_taskPipe fileHandleForReading] readInBackgroundAndNotifyForModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

+(void)initialize {
   if(self==[NSTask_posix class]){
    NSFileHandle *forReading;
    
    _liveTasks=[[NSMutableArray alloc] init];
    _taskPipe=[[NSPipe alloc] init];
    forReading=[_taskPipe fileHandleForReading];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(signalPipeReadNotification:)
      name:NSFileHandleReadCompletionNotification object:forReading];
    
    [forReading readInBackgroundAndNotifyForModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
   }
}

-(int)processIdentifier {
   return _processID;
}

-(void)launch {
   if(launchPath==nil)
    [NSException raise:NSInvalidArgumentException
                format:@"NSTask launchPath is nil"];

   _processID = fork(); 
   if (_processID == 0) {  // child process
       NSMutableArray *array = [[arguments mutableCopy] autorelease];
       const char     *path = [launchPath cString];
       NSInteger            i,count=[array count];
       char          *args[count+1];
       
       if (array == nil)
           array = [NSMutableArray array];

       [array insertObject:launchPath atIndex:0];
       for(i=0;i<count;i++)
        args[i]=(char *)[[[array objectAtIndex:i] description] cString];
       args[i]=NULL;
       
       if ([standardOutput isKindOfClass:[NSFileHandle class]] || [standardOutput isKindOfClass:[NSPipe class]]) {
           int fd = -1;
           
           close(STDIN_FILENO);
           if ([standardInput isKindOfClass:[NSFileHandle class]])
               fd = [(NSFileHandle_posix *)standardOutput fileDescriptor];
           else
               fd = [(NSFileHandle_posix *)[standardOutput fileHandleForReading] fileDescriptor];

           dup2(fd, STDIN_FILENO);
       }
       if ([standardOutput isKindOfClass:[NSFileHandle class]] || [standardOutput isKindOfClass:[NSPipe class]]) {
           int fd = -1;

           close(STDOUT_FILENO);
           if ([standardOutput isKindOfClass:[NSFileHandle class]])
               fd = [(NSFileHandle_posix *)standardOutput fileDescriptor];
           else
               fd = [(NSFileHandle_posix *)[standardOutput fileHandleForWriting] fileDescriptor];

           dup2(fd, STDOUT_FILENO);
       }
       if ([standardError isKindOfClass:[NSFileHandle class]] || [standardError isKindOfClass:[NSPipe class]]) {
           int fd = -1;

           close(STDERR_FILENO);
           if ([standardError isKindOfClass:[NSFileHandle class]])
               fd = [(NSFileHandle_posix *)standardError fileDescriptor];
           else
               fd = [(NSFileHandle_posix *)[standardError fileHandleForWriting] fileDescriptor];

           dup2(fd, STDERR_FILENO);
       }

       chdir([currentDirectoryPath fileSystemRepresentation]);

       execve(path, args, NSPlatform_environ());
       [NSException raise:NSInvalidArgumentException
                   format:@"NSTask: execve(%s) returned: %s", path, strerror(errno)];
   }
   else if (_processID != -1) {
       isRunning = YES;
       [_liveTasks addObject:self];
   }
   else
       [NSException raise:NSInvalidArgumentException
                   format:@"fork() failed: %s", strerror(errno)];
}

-(void)terminate {
   kill(_processID, SIGTERM);
   [_liveTasks removeObject:self];
}

-(int)terminationStatus { return _terminationStatus; }			// OSX specs this
-(void)setTerminationStatus:(int)terminationStatus { _terminationStatus = terminationStatus; }

-(void)taskFinished {
   isRunning = NO;
   [_liveTasks removeObject:self];
}

@end
