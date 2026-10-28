using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace KioskLockApp.Tests
{
    [TestClass]
    public class SelfHostedSupabaseIntegrationTests
    {
        private const string SELF_HOSTED_URL = "http://130.61.78.192:8000";
        private static readonly string ANON_KEY = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String("ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnliMnhsSWpvaVlXNXZiaUlzSW1semN5STZJbk4xY0dGaVlYTmxJaXdpYVdGMElqb3hOemt5TWpJMU9UUTVMQ0psZUhBaU9qRTVORGs1TURVNU5EbDkuc2s4eUJVTFZkNEk4OGQ2emJidllGQnRMRVRpRGhyMElwcTJnRzZFNGloMA=="));

        [TestMethod]
        public async Task SelfHosted_SchoolsEndpoint_Returns_TestSchool()
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Add("apikey", ANON_KEY);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + ANON_KEY);

            var response = await client.GetAsync($"{SELF_HOSTED_URL}/rest/v1/schools?limit=5");
            Assert.IsTrue(response.IsSuccessStatusCode, $"HTTP request failed with status: {response.StatusCode}");

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            Assert.AreEqual(JsonValueKind.Array, root.ValueKind);
            Assert.IsTrue(root.GetArrayLength() > 0);

            var firstSchool = root[0];
            Assert.IsFalse(string.IsNullOrEmpty(firstSchool.GetProperty("name").GetString()));
            Assert.IsTrue(firstSchool.TryGetProperty("is_licensed", out _));
        }

        [TestMethod]
        public async Task SelfHosted_BoardsEndpoint_Returns_TestBoards()
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Add("apikey", ANON_KEY);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + ANON_KEY);

            var response = await client.GetAsync($"{SELF_HOSTED_URL}/rest/v1/boards?limit=5");
            Assert.IsTrue(response.IsSuccessStatusCode, $"HTTP request failed with status: {response.StatusCode}");

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            Assert.AreEqual(JsonValueKind.Array, root.ValueKind);
            Assert.IsTrue(root.GetArrayLength() >= 1);
        }

        [TestMethod]
        public async Task SelfHosted_AppVersions_Returns_v210_And_Zip_Is_Downloadable()
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Add("apikey", ANON_KEY);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + ANON_KEY);

            var response = await client.GetAsync($"{SELF_HOSTED_URL}/rest/v1/app_versions?select=version_number,download_url&order=created_at.desc&limit=1");
            Assert.IsTrue(response.IsSuccessStatusCode);

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            Assert.IsTrue(root.GetArrayLength() > 0);

            var latest = root[0];
            string version = latest.GetProperty("version_number").GetString()!;
            Assert.IsTrue(version.StartsWith("2.1"), $"Version should be 2.1.x, got: {version}");

            string downloadUrl = latest.GetProperty("download_url").GetString()!;
            Assert.IsTrue(downloadUrl.Contains("TahtaUpdate_v") && downloadUrl.EndsWith(".zip"), $"Invalid download url: {downloadUrl}");

            // Zip dosyasının HTTP üzerinden gerçekten inebildiğini doğrula (HEAD request)
            var headReq = new HttpRequestMessage(HttpMethod.Head, downloadUrl);
            var headResp = await client.SendAsync(headReq);
            Assert.IsTrue(headResp.IsSuccessStatusCode, $"Head request failed with: {headResp.StatusCode} for URL: {downloadUrl}");
            long length = headResp.Content.Headers.ContentLength ?? 0;
            if (length == 0)
            {
                // Storage server might only return Content-Length on GET
                var getReq = new HttpRequestMessage(HttpMethod.Get, downloadUrl);
                getReq.Headers.Range = new System.Net.Http.Headers.RangeHeaderValue(0, 1024);
                var getResp = await client.SendAsync(getReq);
                Assert.IsTrue(getResp.IsSuccessStatusCode);
            }
            else
            {
                Assert.IsTrue(length > 1000000, $"ContentLength: {length}");
            }
        }
    }
}
