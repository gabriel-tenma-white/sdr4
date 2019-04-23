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

void concat(u8* buf, int& index, u8* data, int len) {
	memcpy(buf+index, data, len);
	index += len;
}
u32 spiTransaction(u32 din, int bits) {
	// bit pattern:
	// smp 0 0 0 0 sdi cs clk
	
	// pull down cs pin
	u8 buf[256] = {
		0b00000010,
		0b00000010,
		0b00000010,
		0b00000000,
		0b00000000,
		0b00000000,
		0b00000000
	};
	int index = 7;
	
	// send data bits and sample dout bits
	din <<= (32-bits);
	for(int i=0;i<bits;i++) {
		u32 bit = din>>31;
		u8 tmp[4] = {
			0b00000001,
			0b00000001,
			0b10000000,		// MSB of 1 means to sample gpio inputs
			0b00000000
		};
		tmp[0] |= bit<<2;
		tmp[1] |= bit<<2;
		tmp[2] |= bit<<2;
		tmp[3] |= bit<<2;
		concat(buf, index, tmp, sizeof(tmp));
		din <<= 1;
	}
	
	// release cs pin
	{
		u8 tmp[7] = {
			0b00000000,
			0b00000000,
			0b00000000,
			0b00000000,
			0b00000010,
			0b00000010,
			0b00000010,
		};
		concat(buf, index, tmp, sizeof(tmp));
	}
	
	// write commands to tty device
	for(int i=0;i<index;i++)
		buf[i] |= 0b10000000;
	assert(writeAll(ttyFD, buf, index) == index);
	
	// read back data
	u8 buf2[bits*4+14];
	assert(readAll(ttyFD,buf2,sizeof(buf2)) == (int)sizeof(buf2));
	u32 ret = 0;
	for(int i=0; i<bits; i++) {
		u32 bit = (buf2[i*4+7+2]&0b1000)?1:0;
		ret = (ret<<1) | bit;
	}
	return ret;
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
	
	
	/*{
		// spi instruction
		u32 spiData = 0b100000;
		// register address
		spiData <<= 10; spiData |= 0x36;
		// register data
		spiData <<= 8; spiData |= 0xaa;
		u32 spiDout = spiTransaction(spiData, 6 + 10 + 8);
	}*/
	
	for(int i=0; i<0x32; i++) {
		// spi instruction
		u32 spiData = 0b000000;
		// register address
		spiData <<= 10; spiData |= (0x036 + i);
		// register data
		spiData <<= 8; spiData |= 0x00;
		u32 spiDout = spiTransaction(spiData, 6 + 10 + 8);
		spiDout &= 0xff;
		printf("%02x ", spiDout);
		fflush(stdout);
		//sleep(1);
		drainfd(ttyFD);
	}
	printf("\n");
	
	return 0;
}
