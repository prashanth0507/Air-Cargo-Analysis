show databases;

use aircargo_29;

show tables;

drop database if exists aircargo_29;

desc customer;

## Creating route_details table
create table route_details (
	route_id	tinyint 	primary key,
    flight_num	smallint	not null check (flight_num > 0),
    orig_airport	char(3)	not null,
    dest_airport	char(3)	not null,
    aircraft_id		varchar(10) not null,
    distance_miles	smallint	not null check (distance_miles > 0)
);

desc route_details;

select * from customer limit 10;

select * from routes limit 10;

select * from passengers;

alter table passengers modify
	column aircraft_id varchar(10) not null;
    
create table passengers_1  like passengers;

alter table passengers_1 modify column
	customer_id smallint not null first;

desc passengers_1;
insert into passengers_1 
	select customer_id,
		trim(aircraft_id),
        route_id,
        trim(depart),
        trim(arrival),
        trim(seat_num),
        trim(class_id),
        str_to_date(trim(travel_date), '%Y-%m-%d'),
        flight_num
	from passengers_on_flights;
        
select * from  passengers_on_flights limit 2;

select * from passengers_1 limit 5;


## 3
select p.customer_id, 
	concat_ws(', ', c.first_name, c.last_name) as customer_name,
    p.aircraft_id, 
    p.route_id,
    p.depart,
    p.arrival,
    p.seat_num,
    p.class_id,
    p.travel_date,
	p.flight_num
from passengers as p
inner join customer as c using(customer_id)
where p.route_id between 1 and 25;

select * from ticket limit 10;

## 4
select count(customer_id) as number_of_passengers,
		sum(no_of_tickets * price_per_ticket) as Total_revenue
from ticket
where class_id = 'Bussiness'
group by class_id;

## 6
select c.* 
from customer as c
where exists (select customer_id from ticket as t
where t.customer_id = c.customer_id);

select c.* 
from customer as c
where c.customer_id in  (select distinct customer_id from ticket );

## 7
select c.first_name, c.last_name
from customer as c
where exists (select customer_id from ticket as t
where t.customer_id = c.customer_id and
	t.brand = 'Emirates');

## 8

select c.first_name, c.last_name
from customer as c
inner join ticket as t
	using (customer_id)
where t.class_id = 'Economy Plus'
group by t.customer_id
having (count(t.customer_id) > 1);

## 9

select sum(no_of_tickets * price_per_ticket) as Revenue,
	if (sum(no_of_tickets * price_per_ticket) > 10000, 'Revenue more than 10000','Did not achieve the target') as target
from ticket;

## 11
select distinct class_id,
	max(price_per_ticket) over (partition by class_id) as Max_ticket_price
from ticket
order by 2 desc;

select class_id, max(price_per_ticket) from ticket
group by class_id
order by 2 desc;

## 12 
select * from passengers
where route_id = 4;

show indexes from passengers;

## 13
## Manually checking the query plan using 'explain' command
explain select * from passengers
where route_id = 4;

## 15
select customer_id, aircraft_id, 
	sum(no_of_tickets * price_per_ticket) as total_price
from ticket
group by customer_id, aircraft_id with rollup;

## 16

drop procedure if exists sp_get_pass_dtls;

delimiter $$

create procedure sp_get_pass_dtls (
	IN	p_start_route	int,
    IN	p_end_route		int,
    OUT	p_err_msg		varchar(100)
)
BEGIN
	declare continue handler for
		sqlstate '42S02'
        select "SQLSTATE - Table Not Found " into p_err_msg;
        
	DECLARE continue handler for
		sqlexception
        begin
			GET diagnostics CONDITION 1
            @sqlstate = RETURNED_SQLSTATE,
            @errorno = MYSQL_ERRNO,
            @text = message_text;
            
			set @full_error = concat("SQL Exception Handler - Error", @errorno, 
				"( SQL State : ", @sqlstate, ")", @text);
			select @full_error into p_err_msg;
		end;
		
        select c.* from customer as c
        inner join passengers as p
        where p.route_id between p_start_route and p_end_route and
				c.customer_id = p.customer_id;
                
        set p_err_msg = "Table Found";
END $$

delimiter ;


call sp_get_pass_dtls(10, 15, @msg);
select @msg;

rename table passengers to passgrs;

rename table passgrs to passengers;

## 18
drop function if exists distance_travelled;

delimiter $$

create function distance_travelled (
	dis_miles 	int
)
RETURNS varchar(20)
DETERMINISTIC
BEGIN

	declare v_dis_info 	char(3);
    
	case  
		when dis_miles < 2000 then set v_dis_info = 'SDT';
        when dis_miles  < 6500 then set v_dis_info = 'IDT';
        else
			set v_dis_info = 'LDT';
	end case;
    return v_dis_info;
END $$

delimiter ;

drop procedure if exists sp_distance_travelled;

delimiter $$

create procedure sp_distance_travelled ()
BEGIN
	select distance_miles, 
		distance_travelled(distance_miles) as dist_description
	from routes
	order by 2;
END $$

delimiter ;

call sp_distance_travelled;

## 19

drop function if exists getCompService;

delimiter $$
CREATE FUNCTION getCompService(
	class_id 	varchar(20)
) 
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE compService VARCHAR(20);

    IF class_id in ('Bussiness', 'Economy Plus') THEN
		SET compService = 'Yes';
    ELSE
        SET compService = 'No';
    END IF;
	-- return the complementary Services
	RETURN (compService);
END$$

DELIMITER ; 

drop procedure if exists sp_get_ticket_details;

delimiter $$
create procedure sp_get_ticket_details ()
BEGIN

	select p_date as Purchase_Date,
			customer_id as Customer,
            class_id as Class,
            getCompService(class_id) as Complementary_Service
	from
		ticket;
END $$

delimiter ;

call sp_get_ticket_details;


select getCompService('Economy');

## 20
drop procedure if exists getCustName;

DELIMITER $$

CREATE PROCEDURE getCustName (
	in p_last_name 	varchar(20) 
)
BEGIN
	DECLARE finished INTEGER DEFAULT 0;
	DECLARE v_full_name varchar(100) DEFAULT "";
    DECLARE v_dob		date;
    DECLARE	v_gender	char(1);
	DECLARE v_last_name	varchar(20);
  
	-- declare cursor for employee email
	DECLARE getCustomer 
		CURSOR FOR 
			SELECT 
				concat(first_name, ' ', last_name) as full_name,
                dob,
                gender
            FROM customer
            WHERE	last_name = v_last_name;

	-- declare NOT FOUND handler
	DECLARE CONTINUE HANDLER 
        FOR NOT FOUND SET finished = 1;
        
	if isnull(p_last_name) then
		set v_last_name = 'Scott';
	else
		set v_last_name = p_last_name;
	end if;
    
	OPEN getCustomer;

	cust: LOOP
		FETCH getCustomer INTO v_full_name, v_dob, v_gender;
		IF finished = 1 THEN 
			LEAVE cust;
		END IF;

		SELECT
			v_full_name, v_dob, v_gender;
	END LOOP cust;
	CLOSE getCustomer;

END$$

DELIMITER ;

call getCustName(NULL);
call getCustName('Sam');
