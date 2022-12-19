package ru.fivt.dostavimvse;

import io.github.bonigarcia.wdm.WebDriverManager;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.openqa.selenium.By;
import org.openqa.selenium.NoSuchElementException;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.chrome.ChromeDriver;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;

import static org.junit.Assert.*;

import java.util.concurrent.TimeUnit;

@RunWith(SpringJUnit4ClassRunner.class)
@SpringBootTest
public class FrontendTest {
    static class ApplicationThread extends Thread {
        @Override
        public void run() {
            String[] strings = {};
            DostavimvseApplication.main(strings);
        }
    }

    Thread applicationThread;

    @Before
    public void createFixture() throws InterruptedException {
        applicationThread = new ApplicationThread();
        applicationThread.start();
        TimeUnit.SECONDS.sleep(5); // Wait some time for server to start
    }

    @After
    public void shutdownFixture() {
        applicationThread.stop();
    }

    @Test
    public void testFrontend() throws InterruptedException {
        // run 'init-base' before everything

        WebDriverManager.chromedriver().setup();
        WebDriver driver = new ChromeDriver();
        driver.get("http://localhost:8080");

        // Main page

        driver.findElement(By.id("get-order-history")).click();
        TimeUnit.MILLISECONDS.sleep(500);

        // Page with orders

        int receivingCount = driver.findElements(By.tagName("tbody")).get(1).findElements(By.tagName("tr")).size();
        assertTrue("Not enough receiving items", receivingCount >= 1);
        driver.findElement(By.id("main-page")).click();
        TimeUnit.MILLISECONDS.sleep(500);

        // Main page

        driver.findElement(By.id("create-order-button")).click();
        TimeUnit.MILLISECONDS.sleep(500);

        // Create order page

        driver.findElement(By.id("receiver-id")).sendKeys("1");
        driver.findElement(By.id("start-vertex-id")).sendKeys("1");
        driver.findElement(By.id("end-vertex-id")).sendKeys("3");
        driver.findElement(By.className("weight-input")).sendKeys("0.1");
        driver.findElement(By.className("price-input")).sendKeys("0.2");
        driver.findElement(By.id("send-order")).click();
        TimeUnit.MILLISECONDS.sleep(500);

        // Created order info

        String orderId = driver.findElement(By.className("order_id")).findElement(By.tagName("span")).getText();
        assertEquals(driver.findElement(By.className("order_status")).findElement(By.tagName("span")).getText(), "WAIT_CHANGE");
        assertEquals(driver.findElement(By.className("order_receiver")).findElement(By.tagName("span")).getText(), "1");

        driver.findElement(By.id("main-page")).click();
        TimeUnit.MILLISECONDS.sleep(500);

        // Main page

        driver.findElement(By.id("get-order-input")).sendKeys(orderId);
        driver.findElement(By.id("get-order-button")).click();
        TimeUnit.MILLISECONDS.sleep(500);

        // Page with order info

        assertEquals(driver.findElement(By.className("order_id")).findElement(By.tagName("span")).getText(), orderId);
        assertEquals(driver.findElement(By.className("order_start_vertex")).findElement(By.tagName("span")).getText(), "1");
        assertEquals(driver.findElement(By.className("order_end_vertex")).findElement(By.tagName("span")).getText(), "3");

        WebElement receiveOrder = null;
        for (int i = 0; receiveOrder == null && i < 100; ++i) {
            TimeUnit.SECONDS.sleep(1);
            driver.navigate().refresh();
            try {
                receiveOrder = driver.findElement(By.id("receive-order-button"));
            } catch (NoSuchElementException ignored) {}
        }
        assertNotNull("Order must arrive to dest point", receiveOrder);
        receiveOrder.click();
        TimeUnit.MILLISECONDS.sleep(500);

        driver.switchTo().alert().accept();
        TimeUnit.MILLISECONDS.sleep(500);

        assertEquals(driver.findElement(By.className("order_status")).findElement(By.tagName("span")).getText(), "COMPLETED");

        driver.close();
    }
}
