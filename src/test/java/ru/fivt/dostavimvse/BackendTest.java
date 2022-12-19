package ru.fivt.dostavimvse;

import org.hibernate.Session;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringJUnit4ClassRunner;
import ru.fivt.dostavimvse.models.*;

import java.time.LocalDateTime;
import java.util.Set;

import static org.junit.Assert.assertEquals;

@RunWith(SpringJUnit4ClassRunner.class)
@SpringBootTest
public class BackendTest {
    Session session;
    Client client1;
    Client client2;

    @Before
    public void createFixture() {
        session = HibernateSessionFactory.getSessionFactory().openSession();
        session.beginTransaction();
        client1 = new Client();
        client2 = new Client();
        session.save(client1);
        session.save(client2);
        session.getTransaction().commit();
        System.out.println("Created new clients with ids " + client1.getId() + " and " + client2.getId());
    }

    @Test
    public void testOrderController() throws InterruptedException {
        OrderController orderController = new OrderController();

        Order order = new Order();
        order.setStartDate(LocalDateTime.now());
        order.setStartVertex(0);
        order.setEndVertex(9);
        order.setOrderType(OrderType.TIME);

        Product product = new Product();
        product.setWeight(0.8);
        product.setPrice(0.4);
        product.setOrder(order);

        Set<Product> products = order.getProducts();
        products.add(product);
        order.setProducts(products);

        JSONObject response = new JSONObject(orderController.createOrder(client1.getId(), client2.getId(), order));
        assertEquals(response.getJSONArray("code").getInt(0), 200);
        int orderId = response.getJSONArray("orderId").getInt(0);
        System.out.println("Order id = " + orderId);
        Order dbOrder = session.get(Order.class, orderId);
        assertEquals(dbOrder.getStartVertex(), order.getStartVertex());
        assertEquals(dbOrder.getEndVertex(), order.getEndVertex());
        assertEquals(dbOrder.getProducts().size(), order.getProducts().size());

        session.beginTransaction();
        dbOrder.setOrderStatus(OrderStatus.READY);
        session.save(dbOrder);
        session.getTransaction().commit();

        response = new JSONObject(orderController.receiverOrder(client2.getId(), orderId));
        assertEquals(response.getJSONArray("code").getInt(0), 200);
    }

    @Test
    public void testOptimalSolver() {
        Order order = new Order();
        order.setStartDate(LocalDateTime.now());
        order.setStartVertex(1);
        order.setEndVertex(3);

        Route route = new OptimalTimeSolver().buildOptimalRoute(order);
        assertEquals(route.getRouteLegs().size(), 1);
        Leg leg = route.getRouteLegs().iterator().next().getLeg();
        assertEquals((int) leg.getStartVertex(), 1);
        assertEquals((int) leg.getEndVertex(), 3);

        route = new OptimalPriceSolver().buildOptimalRoute(order);
        assertEquals(route.getRouteLegs().size(), 1);
        leg = route.getRouteLegs().iterator().next().getLeg();
        assertEquals((int) leg.getStartVertex(), 1);
        assertEquals((int) leg.getEndVertex(), 3);
    }
}
