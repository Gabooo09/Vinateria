-- 1. Verificar existencia del proveedor y empleado
CREATE OR REPLACE FUNCTION existencia_proveedor(_id_proveedor numeric, _id_empleado numeric)
RETURNS BOOLEAN 
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM proveedores WHERE id_proveedor = _id_proveedor) THEN
        IF EXISTS (SELECT 1 FROM empleados WHERE id_empleado = _id_empleado) THEN
            RETURN TRUE;
        ELSE
            RAISE NOTICE 'El empleado no existe: %', _id_empleado;
            RETURN FALSE;
        END IF;
    ELSE
        RAISE NOTICE 'El proveedor no existe: %', _id_proveedor;
        RETURN FALSE;
    END IF;
END;
$$
LANGUAGE plpgsql;

-- 2. Verificar detalles del carrito
CREATE OR REPLACE FUNCTION verdificar_detalles_carrito(_id_proveedor numeric)
RETURNS BOOLEAN 
AS $$
DECLARE
    _tabla RECORD;
BEGIN
    FOR _tabla IN
        SELECT * FROM carrito WHERE id_proveedor = _id_proveedor
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM proveedores_productos 
            WHERE id_proveedor = _tabla.id_proveedor 
              AND id_producto = _tabla.id_producto
        ) THEN
            RAISE EXCEPTION 'El proveedor:% no surte el producto:% del carrito (codigo_id:%).', 
                            _id_proveedor, _tabla.id_producto, _tabla.codigo_id;
            RETURN FALSE;
        END IF;
    END LOOP;
    RETURN TRUE;
END;
$$
LANGUAGE plpgsql;

-- 3. Registrar la compra
CREATE OR REPLACE FUNCTION realizar_compra(_id_empleado numeric, _id_proveedor numeric)
RETURNS int 
AS $$
DECLARE	
    numero_compra int;
BEGIN
    INSERT INTO compras(id_proveedor, id_empleado, fecha_compra)
    VALUES (_id_proveedor, _id_empleado, current_date)
    RETURNING id_compra INTO numero_compra;

    RETURN numero_compra;
END;
$$
LANGUAGE plpgsql;

-- 4. Insertar detalles de la compra
CREATE OR REPLACE FUNCTION insertar_detalles(_id_proveedor numeric, _id_compra numeric)
RETURNS void
AS $$
DECLARE
    tablas RECORD;
    nuevo_id_detalle numeric;
BEGIN
    FOR tablas IN 
        SELECT * FROM carrito WHERE id_proveedor = _id_proveedor
    LOOP
        -- Generar un nuevo ID para id_detalle_compra
        SELECT COALESCE(MAX(id_detalle_compra), 0) + 1 
        INTO nuevo_id_detalle
        FROM detalle_compras;

        -- Insertar cada producto en detalle_compras
        INSERT INTO detalle_compras (id_detalle_compra, id_compra, id_producto, cantidad, precio_costo, subtotal)
        VALUES (
            nuevo_id_detalle,
            _id_compra, 
            tablas.id_producto, 
            tablas.cantidad_proc, 
            tablas.total_produc, 
            tablas.cantidad_proc * tablas.total_produc
        );

        -- Actualizar inventario
        UPDATE inventarios
        SET cantidad_disponible = cantidad_disponible + tablas.cantidad_proc
        WHERE id_producto = tablas.id_producto;

        -- Eliminar el producto del carrito
        DELETE FROM carrito WHERE codigo_id = tablas.codigo_id;
    END LOOP;
END;
$$
LANGUAGE plpgsql;

-- 5. Función maestra: Procesar la compra
CREATE OR REPLACE FUNCTION procesar_compra(_id_proveedor numeric, _id_empleado numeric)
RETURNS TEXT
AS $$
DECLARE
    numero_compra int;
BEGIN
    -- Verificar existencia del proveedor y empleado
    BEGIN
        IF NOT existencia_proveedor(_id_proveedor, _id_empleado) THEN
            RETURN 'Error: El proveedor o el empleado no existen.';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN FORMAT('Error en la verificación de existencia: %', SQLERRM);
    END;

    -- Verificar detalles del carrito
    BEGIN
        IF NOT verdificar_detalles_carrito(_id_proveedor) THEN
            RETURN 'Error: Existen productos en el carrito que no son surtidos por el proveedor.';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RETURN FORMAT('Error en la verificación de productos en el carrito: %', SQLERRM);
    END;

    -- Registrar la compra
    BEGIN
        numero_compra := realizar_compra(_id_empleado, _id_proveedor);
    EXCEPTION WHEN OTHERS THEN
        RETURN FORMAT('Error al realizar la compra: %', SQLERRM);
    END;

    -- Insertar detalles de la compra
    BEGIN
        PERFORM insertar_detalles(_id_proveedor, numero_compra);
    EXCEPTION WHEN OTHERS THEN
        RETURN FORMAT('Error al insertar los detalles de la compra: %', SQLERRM);
    END;

    -- Confirmar éxito
    RETURN FORMAT('Compra procesada exitosamente. Número de compra: %', numero_compra);
END;
$$
LANGUAGE plpgsql;
SELECT procesar_compra(1, 1);

