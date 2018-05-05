
#if ANDROID_PLATFORM_SDK_VERSION >= 26 //8.0
#include "android_selinux.h"

int selinux_getenforcemode(int *rc)
{
	if (rc) {
		*rc = security_getenforce();
		return 0;
	}
	return -1;
}

#endif

