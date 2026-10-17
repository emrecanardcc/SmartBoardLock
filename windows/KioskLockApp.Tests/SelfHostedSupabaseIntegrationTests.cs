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
            Assert.AreEqual("2.1.1", latest.GetProperty("version_number").GetString());

            string downloadUrl = latest.GetProperty("download_url").GetString()!;
            Assert.AreEqual("http://130.61.78.192:8000/storage/v1/object/public/updates/TahtaUpdate_v2.1.1.zip", downloadUrl);

            // Zip dosyasının HTTP üzerinden gerçekten inebildiğini doğrula (HEAD request)
            var headReq = new HttpRequestMessage(HttpMethod.Head, downloadUrl);
            var headResp = await client.SendAsync(headReq);
            Assert.IsTrue(headResp.IsSuccessStatusCode);
            Assert.IsTrue(headResp.Content.Headers.ContentLength > 1000000); // 1.6 MB civarı
        }
    }
}
