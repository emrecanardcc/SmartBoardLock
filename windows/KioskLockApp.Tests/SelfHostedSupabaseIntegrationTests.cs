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
        private const string ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzkyMjI1OTQ5LCJleHAiOjE5NDk5MDU5NDl9.sk8yBULVd4I88d6zbbvYFBtLETiDhr0Ipq2gG6E4ih0";

        [TestMethod]
        public async Task SelfHosted_SchoolsEndpoint_Returns_TestSchool()
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Add("apikey", ANON_KEY);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + ANON_KEY);

            var response = await client.GetAsync($"{SELF_HOSTED_URL}/rest/v1/schools?id=eq.a0000000-0000-0000-0000-000000000001");
            Assert.IsTrue(response.IsSuccessStatusCode, $"HTTP request failed with status: {response.StatusCode}");

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            Assert.AreEqual(JsonValueKind.Array, root.ValueKind);
            Assert.IsTrue(root.GetArrayLength() > 0);

            var firstSchool = root[0];
            Assert.AreEqual("Test Atatürk Anadolu Lisesi", firstSchool.GetProperty("name").GetString());
            Assert.IsTrue(firstSchool.GetProperty("is_licensed").GetBoolean());
        }

        [TestMethod]
        public async Task SelfHosted_BoardsEndpoint_Returns_TestBoards()
        {
            using var client = new HttpClient();
            client.DefaultRequestHeaders.Add("apikey", ANON_KEY);
            client.DefaultRequestHeaders.Add("Authorization", "Bearer " + ANON_KEY);

            var response = await client.GetAsync($"{SELF_HOSTED_URL}/rest/v1/boards?school_id=eq.a0000000-0000-0000-0000-000000000001");
            Assert.IsTrue(response.IsSuccessStatusCode, $"HTTP request failed with status: {response.StatusCode}");

            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            Assert.AreEqual(JsonValueKind.Array, root.ValueKind);
            Assert.IsTrue(root.GetArrayLength() >= 2);
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
            Assert.AreEqual("2.1.0", latest.GetProperty("version_number").GetString());

            string downloadUrl = latest.GetProperty("download_url").GetString()!;
            Assert.AreEqual("http://130.61.78.192/TahtaUpdate_v2.1.0.zip", downloadUrl);

            // Zip dosyasının HTTP üzerinden gerçekten inebildiğini doğrula (HEAD request)
            var headReq = new HttpRequestMessage(HttpMethod.Head, downloadUrl);
            var headResp = await client.SendAsync(headReq);
            Assert.IsTrue(headResp.IsSuccessStatusCode);
            Assert.IsTrue(headResp.Content.Headers.ContentLength > 1000000); // 1.6 MB civarı
        }
    }
}
