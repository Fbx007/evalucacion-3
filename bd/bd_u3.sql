-- crear la base de datos
create database if not exists bd_paquexpress;
use bd_paquexpress;

--crear la tabla de agentes para que tenga usuarios y la app sea segura
create table agentes (
    id_agente int not null auto_increment,
    nombre varchar(100) not null,
    username varchar(50) not null unique,
    password_hash varchar(255) not null, 
    primary key (id_agente)
);

--crear la tabla de paquetes  de objetos a entregar
create table paquetes (
    id_paquete varchar(50) not null,
    direccion_destino varchar(255) not null,
    id_agente_asignado int null,
    estado enum('ASIGNADO', 'ENTREGADO', 'FALLIDO') not null default 'ASIGNADO',
    primary key (id_paquete),
    foreign key (id_agente_asignado) references agentes(id_agente)
);

--crear la tabla de registros de entregas para su evidencia que implementa gps y foto
create table entregas (
    id_registro int not null auto_increment,
    id_paquete varchar(50) not null unique,
    fecha_hora datetime not null,
    latitud decimal(10, 8) not null,
    longitud decimal(11, 8) not null,
    foto_evidencia_url varchar(255) not null,
    primary key (id_registro),
    foreign key (id_paquete) references paquetes(id_paquete)
);