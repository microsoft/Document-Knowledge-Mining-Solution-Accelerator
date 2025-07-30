using Microsoft.Extensions.Configuration;

namespace Helpers
{
    public static class AppGlobals
    {
        public static IConfiguration Configuration { get; private set; }

        public static void Init(IConfiguration configuration)
        {
            Configuration = configuration;
        }
    }
}
