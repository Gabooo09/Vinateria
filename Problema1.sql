/*
La vinatería "El Corcho" está desarrollando una página web en la cual cada cliente tiene su propio carrito de compras. 
Los clientes pueden agregar productos a su carrito y generar una venta cuando deseen finalizar su compra. 
Para asegurar la integridad de las transacciones y una correcta gestión del inventario, 
hemos desarrollado un conjunto de funciones y procedimientos en PostgreSQL.

Problema a Resolver
El objetivo es garantizar que solo se generen ventas válidas, asegurando que:

Verificación de Clientes y Empleados: Se debe verificar que tanto el cliente como el empleado 
existen en la base de datos antes de procesar una venta. Esto evita errores en los datos y asegura 
que las ventas se asocien correctamente con clientes y empleados válidos.

Carrito de Compras: El sistema debe comprobar que el carrito de compras del cliente contiene productos 
antes de generar una venta. Si el carrito está vacío, no se debe proceder con la venta. Esto evita la 
creación de ventas sin contenido, que resultarían en inconsistencias en los registros de ventas y en 
el inventario.

Creación y Procesamiento de Ventas: Debe ser posible calcular el total de la venta a partir de los 
productos en el carrito, actualizar el inventario correspondiente y reflejar el monto total de la 
venta en los registros. Todo esto debe hacerse de manera coherente y eficiente, asegurando que los 
datos se mantengan precisos y actualizados.
*/


-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

-- 1. Verificar Cliente y Empleado
CREATE OR REPLACE FUNCTION verificar_cliente_empleado(_cliente_id INT, _empleado_id INT)
RETURNS BOOLEAN
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM clientes WHERE id_cliente = _cliente_id) THEN
        IF EXISTS (SELECT 1 FROM empleados WHERE id_empleado = _empleado_id) THEN
            RETURN TRUE;
        ELSE
            RAISE NOTICE 'No existe el empleado: %', _empleado_id;
            RETURN FALSE;
        END IF;
    ELSE
        RAISE NOTICE 'No existe el cliente: %', _cliente_id;
        RETURN FALSE;
    END IF;
END;
$$
LANGUAGE plpgsql;

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

-- 2. Crear Venta
CREATE OR REPLACE FUNCTION crear_venta(_cliente_id INT, _empleado_id INT, _fecha_venta DATE)
RETURNS INT
AS $$
DECLARE
    _venta_id INT;
BEGIN
    INSERT INTO ventas (id_cliente, id_empleado, fecha_venta, monto_total)
    VALUES (_cliente_id, _empleado_id, _fecha_venta, 0)
    RETURNING id_venta INTO _venta_id;
    
    RETURN _venta_id;
END;
$$
LANGUAGE plpgsql;


-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

-- 3. Procesar Carrito
CREATE OR REPLACE FUNCTION procesar_carrito(_cliente_id INT, _venta_id INT)
RETURNS NUMERIC
AS $$
DECLARE
    producto RECORD;
    total NUMERIC(10, 2) := 0;
    subtotal NUMERIC(10, 2);
BEGIN
    FOR producto IN 
        SELECT * FROM carritos WHERE id_cliente = _cliente_id
    LOOP
        -- Calcular el subtotal
        SELECT precio INTO subtotal FROM productos WHERE id_producto = producto.id_producto;
        subtotal := subtotal * producto.cantidad;
        
        -- Sumar el subtotal al total
        total := total + subtotal;

        -- Insertar el detalle de la venta
        INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_venta)
        VALUES (_venta_id, producto.id_producto, producto.cantidad, subtotal);
        
        -- Actualizar el inventario
        UPDATE inventarios
        SET cantidad_disponible = cantidad_disponible - producto.cantidad,
            fecha_actualizacion = CURRENT_DATE
        WHERE id_producto = producto.id_producto;
    END LOOP;

    -- Actualizar el monto total de la venta
    UPDATE ventas
    SET monto_total = total
    WHERE id_venta = _venta_id;

    RETURN total;
END;
$$
LANGUAGE plpgsql;


-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
-- 4. Vaciar Carrito
CREATE OR REPLACE FUNCTION vaciar_carrito(_cliente_id INT)
RETURNS VOID
AS $$
BEGIN
    DELETE FROM carritos WHERE id_cliente = _cliente_id;
END;
$$
LANGUAGE plpgsql;


-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------

-- 5. Finalmente, la transacción general que llama a las otras.
CREATE OR REPLACE PROCEDURE generar_venta(_cliente_id INT, _empleado_id INT, _fecha_venta DATE)
AS $$
DECLARE
    _venta_id INT;
    total NUMERIC(10, 2);
BEGIN
    IF verificar_cliente_empleado(_cliente_id, _empleado_id) THEN
        -- Verificar si hay productos en el carrito
        IF EXISTS (SELECT 1 FROM carritos WHERE id_cliente = _cliente_id) THEN
            _venta_id := crear_venta(_cliente_id, _empleado_id, _fecha_venta);
            total := procesar_carrito(_cliente_id, _venta_id);
            PERFORM vaciar_carrito(_cliente_id);
        ELSE
            RAISE NOTICE 'El carrito del cliente % está vacío', _cliente_id;
        END IF;
    END IF;
END;
$$
LANGUAGE plpgsql;





-- Generar la venta pasando el id_cliente y el id_empleado

CALL generar_venta(5, 1, CURRENT_DATE);


select * from ventas;
select * from productos;
select * from inventarios;
select * from carritos;
select * from detalle_ventas;

--       id_producto, id_cliente, cantidad
CALL insertar_carrito(1, 6, 5);
CALL insertar_carrito(2, 6, 5);
CALL insertar_carrito(3, 6, 10);











