#include <stdio.h>
#include <unistd.h>
#include <assert.h>
#include <stdint.h>
#include <fcntl.h>
#include <termios.h>
#include <stdlib.h>
#include <poll.h>
#include <string.h>

using namespace std;
typedef int16_t s16;
typedef int32_t s32;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint8_t u8;
typedef uint64_t u64;

int ttyFD = -1;

void drainfd(int fd) {
	pollfd pfd;
	pfd.fd = fd;
	pfd.events = POLLIN;
	while(poll(&pfd,1,0)>0) {
		if(!(pfd.revents&POLLIN)) continue;
		char buf[4096];
		read(fd,buf,sizeof(buf));
	}
}

int writeAll(int fd,void* buf, int len) {
	u8* buf1=(u8*)buf;
	int off=0;
	int r;
	while(off<len) {
		if((r=write(fd,buf1+off,len-off))<=0) break;
		off+=r;
	}
	return off;
}

int readAll(int fd,void* buf, int len) {
	u8* buf1=(u8*)buf;
	int off=0;
	int r;
	while(off<len) {
		if((r=read(fd,buf1+off,len-off))<=0) break;
		off+=r;
	}
	return off;
}



int main(int argc, char** argv) {
	if(argc<2) {
		fprintf(stderr, "usage: %s /PATH/TO/TTY\n", argv[0]);
		return 1;
	}
	ttyFD = open(argv[1],O_RDWR);
	if(ttyFD<0) {
		perror("open tty");
		return 2;
	}
	
	struct termios tc;
	
	/* Set TTY mode. */
	if (tcgetattr(ttyFD, &tc) < 0) {
		perror("tcgetattr");
		exit(1);
	}
	tc.c_iflag &= ~(INLCR|IGNCR|ICRNL|IGNBRK|IUCLC|INPCK|ISTRIP|IXON|IXOFF|IXANY);
	tc.c_oflag &= ~OPOST;
	tc.c_cflag &= ~(CSIZE|CSTOPB|PARENB|PARODD|CRTSCTS);
	tc.c_cflag |= CS8 | CREAD | CLOCAL;
	tc.c_lflag &= ~(ICANON|ECHO|ECHOE|ECHOK|ECHONL|ISIG|IEXTEN);
	tc.c_cc[VMIN] = 1;
	tc.c_cc[VTIME] = 0;
	if (tcsetattr(ttyFD, TCSANOW, &tc) < 0) {
		perror("tcsetattr");
		exit(1);
	}
	
	drainfd(ttyFD);
	
	u8 buf[4096*2];
	u8 prev1=0, prev2=0, curr;
	int state=0;
	uint32_t dat=0;
	while(1) {
		u32 outBuf[4096];
		int outBufPos = 0;
		
		assert(readAll(ttyFD,buf,sizeof(buf))==(int)sizeof(buf));
		for(int i=0;i<(int)sizeof(buf);i++) {
			curr = buf[i];
			if(curr == 0xdd && prev1 == 0xbe && prev2 == 0xef) {
				state = 0;
				dat = 0;
				goto cont;
			}
			if(state == 0) dat = 0;
			dat |= (u32(curr) << (state*8));
			
			state++;
			if(state>2) {
				outBuf[outBufPos++] = dat;
				state=0;
				dat=0;
			}
		cont:
			prev2=prev1;
			prev1=curr;
		}
		for(int i=0;i<outBufPos;i++) {
			s16 I = outBuf[i]&0b111111111111;
			s16 Q = (outBuf[i]>>12)&0b111111111111;
			I <<= 4; I >>= 4;
			Q <<= 4; Q >>= 4;
			printf("%5d %5d\n", I, Q);
		}
	}
	
	return 0;
}
