using AgricastLivestock.Api.Auth;
using AgricastLivestock.Api.Models;
using AgricastLivestock.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Multiple listing photos get uploaded one at a time; make sure Kestrel's
// default body size limit doesn't clip a single photo before it even
// reaches UploadsController's own [RequestSizeLimit] check.
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 10 * 1024 * 1024; // 10MB
});

builder.Services.Configure<SupabaseOptions>(builder.Configuration.GetSection(SupabaseOptions.SectionName));
builder.Services.Configure<MapboxOptions>(builder.Configuration.GetSection(MapboxOptions.SectionName));
builder.Services.AddHttpClient();
builder.Services.AddScoped<SupabaseAuthService>();
builder.Services.AddScoped<SupabaseRestService>();
builder.Services.AddScoped<SupabaseStorageService>();
builder.Services.AddScoped<MapboxDirectionsService>();

builder.Services
    .AddAuthentication(SupabaseAuthenticationHandler.SchemeName)
    .AddScheme<SupabaseAuthSchemeOptions, SupabaseAuthenticationHandler>(SupabaseAuthenticationHandler.SchemeName, _ => { });

builder.Services.AddAuthorization();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Flutter runs on a device/emulator, not a browser origin restricted by CORS
// in the mobile-app case, but keep this open for local web testing / Swagger.
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.MapGet("/", () => Results.Ok(new { status = "ok", service = "agricast-livestock-lite api" }));

app.Run();
