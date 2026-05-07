#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

function argValue(name, fallback) {
  const index = process.argv.indexOf(name);
  if (index === -1 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

function printJSON(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

function valueAsString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function valueAsInteger(value) {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string" && value.trim()) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function valueAsStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.map(valueAsString).filter(Boolean);
}

function mergeLinkedApp(apps, seenAppIDs, app) {
  const adamId = valueAsInteger(app?.adamId);
  if (!adamId || seenAppIDs.has(adamId)) return;

  seenAppIDs.add(adamId);
  apps.push({
    adamId,
    appName: valueAsString(app.appName) || `App ID ${adamId}`,
    developerName: valueAsString(app.developerName) || "",
    countryOrRegionCodes: valueAsStringArray(app.countryOrRegionCodes)
  });
}

function collectLinkedApps(value, apps = [], seenAppIDs = new Set()) {
  if (Array.isArray(value)) {
    for (const child of value) {
      collectLinkedApps(child, apps, seenAppIDs);
    }
    return apps;
  }

  if (!value || typeof value !== "object") {
    return apps;
  }

  const adamId = valueAsInteger(value.adamId);
  if (adamId && value.deleted !== true && !seenAppIDs.has(adamId)) {
    mergeLinkedApp(apps, seenAppIDs, {
      adamId,
      appName: valueAsString(value.appName) || valueAsString(value.app?.name) || `App ID ${adamId}`,
      developerName: valueAsString(value.developerName) || "",
      countryOrRegionCodes: valueAsStringArray(value.countriesOrRegions)
    });
  }

  for (const child of Object.values(value)) {
    collectLinkedApps(child, apps, seenAppIDs);
  }

  return apps;
}

async function fetchReportingLinkedApps(page, xsrfToken) {
  return page.evaluate(async ({ xsrfToken }) => {
    const valueAsString = (value) => {
      if (typeof value !== "string") return null;
      const trimmed = value.trim();
      return trimmed.length > 0 ? trimmed : null;
    };
    const valueAsInteger = (value) => {
      if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
      if (typeof value === "string" && value.trim()) {
        const parsed = Number.parseInt(value, 10);
        return Number.isFinite(parsed) ? parsed : null;
      }
      return null;
    };
    const valueAsStringArray = (value) => (
      Array.isArray(value) ? value.map(valueAsString).filter(Boolean) : []
    );
    const endDate = new Date();
    const startDate = new Date(endDate);
    startDate.setUTCDate(startDate.getUTCDate() - 7);

    const body = {
      operationName: "getReportsByCampaign",
      variables: {
        reportOptions: {
          filter: {
            startTime: startDate.toISOString().slice(0, 10),
            endTime: endDate.toISOString().slice(0, 10),
            timeZone: "UTC",
            returnGrandTotals: true,
            returnRowTotals: true,
            selector: {
              pagination: { offset: 0, limit: 50 },
              orderBy: [{ field: "localSpend", sortOrder: "DESCENDING" }]
            },
            returnRecordsWithNoMetrics: true
          }
        }
      },
      query: `query getReportsByCampaign($reportOptions: CampaignsReportOptions!) {
        reportingV5 {
          getReportsByCampaign(reportOptions: $reportOptions) {
            row {
              metadata {
                ... on ReportingCampaign {
                  countriesOrRegions
                  app {
                    appName
                    adamId
                    __typename
                  }
                  __typename
                }
                __typename
              }
              __typename
            }
            __typename
          }
          __typename
        }
      }`
    };

    const response = await fetch("/cm/../reporting/graphql", {
      method: "POST",
      credentials: "include",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-XSRF-TOKEN-CM": xsrfToken,
        "X-Requested-With": "XMLHttpRequest"
      },
      body: JSON.stringify(body)
    });

    const text = await response.text();
    if (!response.ok || text.toLowerCase().includes("<html")) {
      return [];
    }

    const payload = JSON.parse(text);
    const rows = payload?.data?.reportingV5?.getReportsByCampaign?.row || [];
    const apps = [];
    const seenAppIDs = new Set();
    for (const row of rows) {
      const metadata = row?.metadata;
      const app = metadata?.app;
      const adamId = valueAsInteger(app?.adamId);
      if (!adamId || seenAppIDs.has(adamId)) continue;
      seenAppIDs.add(adamId);
      apps.push({
        adamId,
        appName: valueAsString(app?.appName) || `App ID ${adamId}`,
        developerName: "",
        countryOrRegionCodes: valueAsStringArray(metadata?.countriesOrRegions)
      });
    }
    return apps;
  }, { xsrfToken });
}

async function fetchLinkedApps(page, xsrfToken) {
  const reportingApps = await fetchReportingLinkedApps(page, xsrfToken).catch(() => []);
  if (reportingApps.length > 0) {
    return reportingApps;
  }

  return page.evaluate(async ({ xsrfToken }) => {
    const endpoints = [
      "/cm/api/v5/campaigns",
      "/cm/api/v4/campaigns",
      "/cm/api/v2/campaigns"
    ];

    for (const endpoint of endpoints) {
      const response = await fetch(endpoint, {
        method: "GET",
        credentials: "include",
        headers: {
          "Accept": "application/json",
          "X-XSRF-TOKEN-CM": xsrfToken,
          "X-Requested-With": "XMLHttpRequest"
        }
      });

      const text = await response.text();
      if (!response.ok) {
        continue;
      }

      if (text.toLowerCase().includes("<html")) {
        continue;
      }

      try {
        return JSON.parse(text);
      } catch {
        continue;
      }
    }

    return null;
  }, { xsrfToken }).then((payload) => collectLinkedApps(payload));
}

async function visibleAccountName(page) {
  return page.evaluate(() => {
    const lines = (document.body?.innerText || "")
      .split(/\n+/)
      .map((line) => line.trim())
      .filter(Boolean);
    const ignored = new Set([
      "Recommendations",
      "Terms of Service",
      "Privacy Policy"
    ]);
    return lines.find((line) => !ignored.has(line) && !/^copyright\b/i.test(line)) || null;
  }).catch(() => null);
}

function readStdin() {
  return new Promise((resolve) => {
    let input = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      input += chunk;
    });
    process.stdin.on("end", () => {
      if (!input.trim()) {
        resolve({});
        return;
      }

      try {
        resolve(JSON.parse(input));
      } catch {
        resolve({});
      }
    });
  });
}

async function firstVisibleLocator(page, selectors) {
  for (const frame of page.frames()) {
    for (const selector of selectors) {
      const locator = frame.locator(selector).first();
      if (await locator.count().catch(() => 0) === 0) continue;
      if (await locator.isVisible().catch(() => false)) {
        return locator;
      }
    }
  }

  return null;
}

async function fillFirstVisible(page, selectors, value) {
  const locator = await firstVisibleLocator(page, selectors);
  if (!locator) return false;

  await locator.fill(value);
  return true;
}

async function fillFirstVisibleWhenReady(page, selectors, value, timeoutMs) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() <= deadline) {
    const locator = await firstVisibleLocator(page, selectors);
    if (locator && await locator.isEnabled().catch(() => true)) {
      await locator.fill(value);
      return true;
    }

    await page.waitForTimeout(250);
  }

  return false;
}

async function clickFirstVisible(page, selectors) {
  const locator = await firstVisibleLocator(page, selectors);
  if (!locator) return false;

  await locator.click();
  return true;
}

async function clickFirstVisibleWhenReady(page, selectors, timeoutMs, expectedText = null) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() <= deadline) {
    const locator = await firstVisibleLocator(page, selectors);
    if (locator && await locator.isEnabled().catch(() => true)) {
      if (expectedText) {
        const text = await locator.innerText().catch(() => "");
        if (text.trim() !== expectedText) {
          await page.waitForTimeout(250);
          continue;
        }
      }

      await locator.click();
      return true;
    }

    await page.waitForTimeout(250);
  }

  return false;
}

async function clickLoginButton(page, timeoutMs = 0, expectedText = null) {
  const selectors = [
    "button#sign-in",
    ".signin-v2__buttons-wrapper__button-wrapper:not(.signin-v2__buttons-wrapper__button-wrapper--passkey) button.signin-v2__buttons-wrapper__button-wrapper__button",
    "xpath=//*[contains(concat(' ', normalize-space(@class), ' '), ' signin-v2__buttons-wrapper__button-wrapper__button__text ') and normalize-space(.)='Sign In' and not(ancestor::*[contains(concat(' ', normalize-space(@class), ' '), ' signin-v2__buttons-wrapper__button-wrapper--passkey ')])]/ancestor::button[1]",
    "button[type='submit']",
    "button:has-text('Log In')",
    "button:has-text('Log in')",
    "button:has-text('Login')",
    "button:has-text('Continue')",
    "[role='button']:has-text('Log In')",
    "[role='button']:has-text('Log in')",
    "[role='button']:has-text('Continue')"
  ];

  if (timeoutMs > 0) {
    return clickFirstVisibleWhenReady(page, selectors, timeoutMs, expectedText);
  }

  return clickFirstVisible(page, selectors);
}

async function attemptCredentialLogin(page, credentials, state) {
  if (!credentials?.username || !credentials?.password || state.submittedPassword) {
    return;
  }

  if (!state.submittedUsername) {
    const usernameFilled = await fillFirstVisibleWhenReady(page, [
      "input#account_name_text_field",
      "input[name='accountName']",
      "input[type='email']",
      "input[autocomplete*='username']",
      "input[placeholder*='Apple']"
    ], credentials.username, 8000);

    if (usernameFilled) {
      state.submittedUsername = await clickFirstVisibleWhenReady(page, [
        "button#sign-in",
        "button[type='submit']",
        "button:has-text('Continue')",
        "button:has-text('Next')",
        "[role='button']:has-text('Continue')",
        "[role='button']:has-text('Next')"
      ], 8000, "Continue");

      if (state.submittedUsername) {
        return;
      }
    }
  }

  const passwordFilled = await fillFirstVisibleWhenReady(page, [
    "input#password_text_field",
    "input[name='password']",
    "input[type='password']",
    "input[autocomplete='current-password']",
    "input[autocomplete='off'][type='password']"
  ], credentials.password, 8000);

  if (passwordFilled) {
    const clicked = await clickLoginButton(page, 8000, "Sign In");
    if (!clicked) {
      await page.keyboard.press("Enter");
    }
    state.submittedPassword = true;
  }
}

async function main() {
  const input = await readStdin();
  const loginCredentials = input.loginCredentials;
  let chromium;
  try {
    ({ chromium } = require("playwright"));
  } catch {
    throw new Error("Playwright is not installed. Run `npm install -D playwright` from the repo, then try again.");
  }

  const profileDir = argValue("--profile-dir", path.join(process.cwd(), ".apple-ads-profile"));
  const timeoutMs = Number(argValue("--timeout-ms", "300000"));
  fs.mkdirSync(profileDir, { recursive: true });

  const context = await chromium.launchPersistentContext(profileDir, {
    headless: false,
    viewport: { width: 1280, height: 900 }
  });

  const page = context.pages()[0] || await context.newPage();
  const deadline = Date.now() + timeoutMs;
  const loginState = {
    submittedUsername: false,
    submittedPassword: false
  };

  await page.goto("https://app-ads.apple.com/", { waitUntil: "domcontentloaded" });

  while (Date.now() < deadline) {
    await attemptCredentialLogin(page, loginCredentials, loginState);

    const cookies = await context.cookies("https://app-ads.apple.com");
	    const xsrfCookie = cookies.find((cookie) => cookie.name === "XSRF-TOKEN-CM");
	    const hasAppleAdsSessionCookie = cookies.some((cookie) => cookie.name === "searchads.soid");

	    if (xsrfCookie && hasAppleAdsSessionCookie) {
	      await page.waitForLoadState("networkidle", { timeout: 10000 }).catch(() => {});
	      await page.waitForTimeout(1000);
	      const cookieHeader = cookies
	        .map((cookie) => `${cookie.name}=${cookie.value}`)
	        .join("; ");
      const linkedApps = await fetchLinkedApps(page, xsrfCookie.value).catch(() => []);
      const accountName = await visibleAccountName(page);

      await context.close();
      printJSON({
        status: "success",
        cookieHeader,
        xsrfToken: xsrfCookie.value,
        linkedApps,
        accountName
      });
      return;
    }

    await page.waitForTimeout(1000);
  }

  await context.close();
  printJSON({
    status: "failure",
    cookieHeader: "",
    xsrfToken: "",
    message: "Timed out waiting for Apple Ads login. Complete Apple sign-in and 2FA in the browser, then try again."
  });
}

main().catch((error) => {
  printJSON({
    status: "failure",
    cookieHeader: "",
    xsrfToken: "",
    message: error.message
  });
});
