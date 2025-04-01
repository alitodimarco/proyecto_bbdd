-- número de clases que realiza cada aprendiz y si no tiene clases, mostrar "sin
-- clases"
select a.id_miembro, a.nivel,
if(count(r.clases_id_clases) = 0, 'sin clases',
count(r.clases_id_clases)) as total_clases
from aprendices a left join realizan r
on a.id_miembro = r.aprendices_id_miembro
group by a.id_miembro, a.nivel;

-- aprendices que han realizado más clases que el aprendiz con id 1
select a.id_miembro, a.nivel, count(r.clases_id_clases) as
total_clases
from aprendices a inner join realizan r
on a.id_miembro = r.aprendices_id_miembro
group by a.id_miembro, a.nivel
having count(r.clases_id_clases) > (
select count(r2.clases_id_clases)
from aprendices a2 inner join realizan r2
on a2.id_miembro = r2.aprendices_id_miembro
where a2.id_miembro = 1
);

-- entrenadores con la última clase dada
select e.id_miembro, e.rango, c.horario as ultima_clase, c.nombre as
nombre_clase
from entrenadores e left join clases c
on e.clases_id_clases = c.id_clases
where c.horario = (
select max(c2.horario)
from clases c2
where c2.id_clases = e.clases_id_clases
)
limit 8;

-- mostrar los pagos realizados con tarjetas activas y la matrícula asociada
select p.numero_tarjeta, p.fecha_vencimiento, m.nombre as
nombre_matricula, p.estado_tarjeta
from pago p inner join matricula m
on p.matricula_id_matricula = m.id_matricula
where p.estado_tarjeta = 'activa';

-- entrenadores con el mayor rango de cada clase
select e.id_miembro, e.rango, c.nombre as nombre_clase
from entrenadores e inner join clases c
on e.clases_id_clases = c.id_clases
where e.rango = (
select max(e2.rango)
from entrenadores e2
where e2.rango = 'avanzado'
);



--------------------------------------------------------------------------


-- vistas

-- vista 1: aprendices por nivel
create view vista_aprendices_por_nivel as select
nivel, count(*) as total_aprendices
from aprendices
group by nivel;

-- vista 2: clases aprendices y si no han dado ninguna (sin clases)
create view clases_aprendiz as select a.id_miembro, a.nivel,
if(count(r.clases_id_clases) = 0, 'sin clases',
count(r.clases_id_clases)) as total_clases
from aprendices a left join realizan r
on a.id_miembro = r.aprendices_id_miembro
group by a.id_miembro, a.nivel;





--------------------------------------------------------------------------




-- funciones

-- función 1: contar clases dependiendo del objetivo
delimiter &&

drop function if exists contar_aprendices_objetivo&&

create function contar_aprendices_objetivo(objetivo_buscar varchar(45))
returns int unsigned
deterministic
begin
    declare total int unsigned;

    -- Contar los aprendices con el objetivo especificado
    select count(*)
    into total
    from aprendices
    where objetivo = objetivo_buscar;

    -- Si no se encuentran resultados, establecer total como 0
    if total is null then
        set total = 0;
    end if;

    return total;
end &&

delimiter ;

-- Llamada a la función con el objetivo 'mejorar flexibilidad'
select contar_aprendices_objetivo('mejorar flexibilidad');


-- función 2: contar clases dependiendo del horario que queramos buscar
delimiter &&

drop function if exists contar_clases_horario &&

create function contar_clases_horario(horario_buscar varchar(45))
returns int unsigned
deterministic
begin
    declare total int unsigned;

    -- Contar las clases con el horario especificado
    select count(*)
    into total
    from clases
    where horario = horario_buscar;

    -- Si no se encuentran resultados, establecer total como 0
    if total is null then
        set total = 0;
    end if;

    return total;
end &&

delimiter ;

-- Llamada a la función con el horario 'mañana'
select contar_clases_horario('mañana');







--------------------------------------------------------------------------







-- Procedimiento 1: Contar el total y las tarifas activas dependiendo de la calidad de la tarifa
DELIMITER &&

DROP PROCEDURE IF EXISTS calcular_tarifas_calidad&&
CREATE PROCEDURE calcular_tarifas_calidad(
    IN calidad_buscar VARCHAR(45),
    OUT total_tarifas INT,
    OUT total_activas INT
)
BEGIN
    -- Inicializar las variables
    SET total_tarifas = 0;
    SET total_activas = 0;
    
    -- Contar todas las tarifas para la calidad que elijamos
    SELECT COUNT(*) 
    INTO total_tarifas
    FROM tarifas
    WHERE calidad = calidad_buscar;
    
    -- Contar solo las tarifas activas para la calidad que queramos
    SELECT COUNT(*) 
    INTO total_activas
    FROM tarifas
    WHERE calidad = calidad_buscar 
    AND estado = 'Activo';
END &&

DELIMITER ;

-- ver los distintos tipos de tarifas
SELECT DISTINCT calidad
FROM tarifas;

-- para ver las tarifas premium
CALL calcular_tarifas_calidad('Premium', @total_premium, @activas_premium);
SELECT @total_premium AS Total_Premium, @activas_premium AS Activas_Premium;


-- para ver las tarifas vip
CALL calcular_tarifas_calidad('VIP', @total_vip, @activas_vip);
SELECT @total_vip AS Total_VIP, @activas_vip AS Activas_VIP;


-- para ver las tarifas estandar
CALL calcular_tarifas_calidad('Estándar', @total_estandar, @activas_estandar);
SELECT @total_estandar AS Total_Estandar, @activas_estandar AS Activas_Estandar;








-- Procedimiento 2: Lista los aprendices del nivel que queramos y nos muestra su objetivo

DELIMITER &&

DROP PROCEDURE IF EXISTS listar_aprendices_nivel&&
CREATE PROCEDURE listar_aprendices_nivel(IN nivel_buscar VARCHAR(45))
BEGIN
    SELECT 
        objetivo,
        fecha_finalizacion
    FROM 
        aprendices
    WHERE 
        nivel = nivel_buscar
    ORDER BY 
        fecha_finalizacion;
END &&

DELIMITER ;


CALL listar_aprendices_nivel('Basico');
CALL listar_aprendices_nivel('Intermedio');
CALL listar_aprendices_nivel('Avanzado');






--------------------------------------------------------------------------




-- triggers


-- Creacion de tabla donde se van a guardar los datos que actualicemos.

CREATE TABLE auditoria_cambios (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    tabla_afectada VARCHAR(45),
    accion VARCHAR(45),
    dato_antiguo VARCHAR(45),
    dato_nuevo VARCHAR(45),
    fecha_cambio DATETIME
);



-- Trigger 1: Cambiar objetivo y registrarlo en la tabla auditoria_cambios

DELIMITER &&

DROP TRIGGER IF EXISTS trigger_registrar_cambio_objetivo_aprendices&&
CREATE TRIGGER trigger_registrar_cambio_objetivo_aprendices
AFTER UPDATE
ON aprendices FOR EACH ROW
BEGIN
    DECLARE objetivo_antiguo VARCHAR(45);
    DECLARE objetivo_nuevo VARCHAR(45);

    -- Almacenar los valores antiguo y nuevo en variables
    SET objetivo_antiguo = OLD.objetivo;
    SET objetivo_nuevo = NEW.objetivo;

    -- Si el objetivo ha cambiado, registrar en la tabla de auditoría
    IF objetivo_antiguo != objetivo_nuevo THEN
        INSERT INTO auditoria_cambios (tabla_afectada, accion, dato_antiguo, dato_nuevo, fecha_cambio)
        VALUES ('aprendices', 'UPDATE', objetivo_antiguo, objetivo_nuevo, NOW());
    END IF;
END &&

DELIMITER ;

UPDATE aprendices
SET objetivo = 'ganar flexibilidad'
WHERE id_miembro = 1;


-- por realizar ejemplo
UPDATE aprendices 
SET objetivo = 'Mejorar resistencia' 
WHERE id_miembro = 2;




-- Trigger 2: Insertar el nombre de una clase y la capacidad y que se registre el insert into dentro de la tabla auidoriaç

DELIMITER &&

DROP TRIGGER IF EXISTS trigger_registrar_nueva_clase&&
CREATE TRIGGER trigger_registrar_nueva_clase
AFTER INSERT
ON clases FOR EACH ROW
BEGIN
    DECLARE nombre_clase VARCHAR(45);
    DECLARE capacidad_clase VARCHAR(45);

    -- Almacenar los valores de la nueva clase en variables
    SET nombre_clase = NEW.nombre;
    SET capacidad_clase = NEW.capacidad;

    -- Registrar la inserción en la tabla de auditoría
    INSERT INTO auditoria_cambios (tabla_afectada, accion, dato_antiguo, dato_nuevo, fecha_cambio)
    VALUES ('clases', 'INSERT', NULL, CONCAT(nombre_clase, ' (Capacidad: ', capacidad_clase, ')'), NOW());
END &&

DELIMITER ;






INSERT INTO clases (id_clases, nombre, duracion, horario, capacidad, UBICACION_id_ubicacion)
VALUES (502, 'Intensivo de cardio', '02:00:00', 'Mañana', '15', 13);




--  no realizado

INSERT INTO clases (id_clases, nombre, duracion, horario, capacidad, UBICACION_id_ubicacion)
VALUES (502, 'Pilates Avanzado', '01:30:00', 'Tarde', '25', 10);

