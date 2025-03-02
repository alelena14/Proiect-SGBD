--6. Formula?i în limbaj natural o problemã pe care sã o rezolva?i folosind un subprogram stocat independent 
--care sã utilizeze toate cele 3 tipuri de colec?ii studiate. Apela?i subprogramul.


create or replace procedure analiza_librarie(
    p_cod_librarie in varchar2
) is

    -- tipuri de date complexe
    type nestedtablecarti is table of varchar2(100); -- lista cartilor si autorilor
    type assocarrayclienti is table of varchar2(100) index by pls_integer; -- clienti comenzi
    type varraygenuri is varray(10) of varchar2(50); -- lista genurilor
   
    carti nestedtablecarti := nestedtablecarti();
    clienti assocarrayclienti;
    genuri varraygenuri := varraygenuri();

    -- variabile
    v_nume_carte varchar2(100);
    v_autor varchar2(100);
    v_gen varchar2(50);
    v_nume_client varchar2(100);
    v_cod_comanda number;
    v_valoare_totala number := 0; -- suma comenzilor
    v_pret_mediu number := 0;     -- media preturilor cartilor
    v_nr_carti number := 0;       -- numar total carti
    v_nume_librarie varchar2(100);
    
    -- exceptii
    no_data_found_exception exception;

begin
    -- validare parametru
    if p_cod_librarie is null then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Parametrul de intrare este invalid', 6, systimestamp);
        commit;
        raise_application_error(-20001, 'Codul librariei nu poate fi null.');
    end if;

    -- carti si autori din librarie
    for carte in (
        select c.nume_carte, a.nume_autor || ' ' || a.prenume_autor as autor, c.pret_carte
        from carte c
        join autor a on c.cod_autor = a.cod_autor
        where lower(c.cod_librarie) = lower(p_cod_librarie)
    ) loop
        carti.extend;
        carti(carti.count) := carte.nume_carte || ' - ' || carte.autor;
        v_valoare_totala := v_valoare_totala + carte.pret_carte;
        v_nr_carti := v_nr_carti + 1;
    end loop;

    -- calcul media preturilor
    if v_nr_carti > 0 then
        v_pret_mediu := v_valoare_totala / v_nr_carti;
    else
        raise no_data_found_exception;
    end if;

    -- clienti care au comandat din librarie
    for client in (
        select distinct cl.id_client, cl.nume_client || ' ' || cl.prenume_client as numee, c.cod_comanda
        from client cl
        join detalii_comanda dc on cl.id_client = dc.id_client
        join comanda c on dc.cod_comanda = c.cod_comanda
        where lower(dc.cod_librarie) = lower(p_cod_librarie)
    ) loop
        clienti(client.cod_comanda) := client.numee;
    end loop;

    -- statistici pe genuri
    for gen in (
        select g.nume_gen, count(*) as numar
        from carte c
        join gen g on c.cod_gen = g.cod_gen
        where lower(c.cod_librarie) = lower(p_cod_librarie)
        group by g.nume_gen
    ) loop
        if genuri.count < genuri.limit then
            genuri.extend;
            genuri(genuri.count) := gen.nume_gen || ' (' || gen.numar || ')';
        end if;
    end loop;
    
    select nume_librarie
    into v_nume_librarie
    from librarie
    where lower(p_cod_librarie)=lower(cod_librarie);

    -- output carti
    dbms_output.put_line('--------------------------------------------');
    dbms_output.put_line('Cartile din libraria "' || v_nume_librarie || '":');
    dbms_output.put_line('--------------------------------------------');
    if carti.count = 0 then
        dbms_output.put_line('Nu exista carti in aceasta librarie.');
    else
        for i in 1 .. carti.count loop
            dbms_output.put_line(carti(i));
        end loop;
    end if;

    -- output clien?i
    dbms_output.put_line(' ');
    dbms_output.put_line('--------------------------------------------');
    dbms_output.put_line('Clientii care au facut comenzi:');
    if clienti.count = 0 then
        dbms_output.put_line('Nu exista clienti care au comandat din aceasta librarie.');
    else
        for indx in clienti.first .. clienti.last loop
            if clienti.exists(indx) then
                dbms_output.put_line('Comanda ' || indx || ' : ' || clienti(indx));
            end if;
        end loop;
    end if;

    -- output statistici genuri
    dbms_output.put_line(' ');
    dbms_output.put_line('--------------------------------------------');
    dbms_output.put_line('Statistici pe genuri:');
    if genuri.count = 0 then
        dbms_output.put_line('Nu exista statistici pentru genuri.');
    else
        for i in 1 .. genuri.count loop
            dbms_output.put_line(genuri(i));
        end loop;
    end if;

    -- output statistici suplimentare
    dbms_output.put_line(' ');
    dbms_output.put_line('--------------------------------------------');
    dbms_output.put_line('Statistici suplimentare:');
    dbms_output.put_line('Valoarea totala a cartilor: ' || to_char(v_valoare_totala, '999,990.00'));
    dbms_output.put_line('Pretul mediu al cartilor: ' || to_char(v_pret_mediu, '999,990.00'));

exception
    when no_data_found_exception then
        dbms_output.put_line('Eroare: nu exista date pentru libraria specificata.');
    when others then
        dbms_output.put_line('Eroare neasteptata: ' || sqlerrm);
end analiza_librarie;
/

select * from log_erori;
begin
   analiza_librarie(null);
end;
/
-----------------------------------------------------------------------------------------------------------------------------------
--7. Formula?i în limbaj natural o problemã pe care sã o rezolva?i folosind un subprogram stocat independent
--care sã utilizeze 2 tipuri diferite de cursoare studiate, unul dintre acestea fiind cursor parametrizat,
--dependent de celãlalt cursor. Apela?i subprogramul.

create or replace procedure raport_comenzi_perioada(
    p_data_inceput in date,
    p_data_sfarsit in date
) is
    cursor_comenzi sys_refcursor;

    cursor cursor_produse(p_cod_comanda number) is
        select c.nume_carte, c.pret_carte
        from carte_comanda cc
        join carte c on cc.cod_carte = c.cod_carte
        where cc.cod_comanda = p_cod_comanda;

    v_nume_produs varchar2(100);
    v_pret number;
    v_nume_client varchar2(100);
    v_cod_comanda number;
    v_data_plasare date;
    v_cod_client number;
    v_exista_comenzi boolean := false; -- verificarea existentei comenzilor

begin
    -- validare parametri
    if p_data_inceput is null or p_data_sfarsit is null then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Parametrii de intrare sunt invalizi', 7, systimestamp);
        commit;
        raise_application_error(-20001, 'Datele de inceput si de sfarsit nu pot fi null.');
    end if;

    if p_data_inceput > p_data_sfarsit then
    insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Data de inceput nu este anterioara datei de sfarsit.', 7, systimestamp);
        commit;
        raise_application_error(-20002, 'Data de inceput trebuie sa fie anterioara datei de sfarsit.');
    end if;

    -- deschidere cursor principal
    open cursor_comenzi for
        'select c.cod_comanda, c.data_plasare_comanda, dc.id_client as codclient
         from comanda c
         join detalii_comanda dc on c.cod_comanda = dc.cod_comanda
         where c.data_plasare_comanda between :1 and :2'
    using p_data_inceput, p_data_sfarsit;

    loop
        fetch cursor_comenzi into v_cod_comanda, v_data_plasare, v_cod_client;
        exit when cursor_comenzi%notfound;
        v_exista_comenzi:=true;
        
        -- cautare clienti pentru comenzi
        begin
            select c.nume_client || ' ' || c.prenume_client
            into v_nume_client
            from client c
            where c.id_client = v_cod_client;
            
        -- exceptie daca nu exista client cu id ul respectiv
        exception
            when no_data_found then
                insert into log_erori (mesaj, nr_exercitiu, data_eroare)
                values ('Clientul cu id ' || v_cod_client || ' nu exista.', 7, systimestamp);
                commit;
                raise_application_error(-20003,'Eroare: Clientul cu id ' || v_cod_client || ' nu exista.');
        end;

        dbms_output.put_line('Comanda ' || v_cod_comanda || 
                             ' - Client: ' || v_nume_client || 
                             ' - Data: ' || to_char(v_data_plasare, 'dd-mm-yyyy'));

        declare
            v_exista_carti boolean := false;
        begin
            for carte in cursor_produse(v_cod_comanda) loop
                v_exista_carti := true;
                dbms_output.put_line('    Titlu: ' || carte.nume_carte || ' - Pret: ' || carte.pret_carte);
            end loop;
            
            -- exceptie daca nu exista carti la comanda
            if not v_exista_carti then
                insert into log_erori (mesaj, nr_exercitiu, data_eroare)
                values ('Comanda '|| v_cod_comanda ||' nu are carti asociate.', 7, systimestamp);
                commit;
                raise_application_error(-20004,'Aceasta comanda nu are carti asociate.');
            end if;
        end;
        
    end loop;

    close cursor_comenzi;
    
    -- exceptie daca nu exista comenzi in perioada specificata
    if not v_exista_comenzi then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Nu exista comenzi in perioada: '|| p_data_inceput ||' - '|| p_data_sfarsit ||'.', 7, systimestamp);
        commit;
        raise_application_error(-20005, 'Nu exista comenzi pentru perioada specificata.');
    end if;
    
exception
    when others then
        if cursor_comenzi%isopen then
            close cursor_comenzi;
        end if;
        raise_application_error(-20006, 'Eroare in procedura: ' || sqlerrm);
end raport_comenzi_perioada;
/


select* from log_erori;

begin
    raport_comenzi_perioada(
        to_date('20-03-2024', 'dd-mm-yyyy') , 
        to_date('22-06-2024', 'dd-mm-yyyy')  
    );
end;
/

--------------------------------------------------------------------------------------------------------------
--8. Formula?i în limbaj natural o problemã pe care sã o rezolva?i folosind un subprogram stocat independent
--de tip func?ie care sã utilizeze într-o singurã comandã SQL 3 dintre tabelele create. Trata?i toate excep?iile 
--care pot apãrea, incluzând excep?iile predefinite NO_DATA_FOUND ?i TOO_MANY_ROWS. Apela?i subprogramul astfel încât sã eviden?ia?i toate cazurile tratate.

create or replace function obtine_carte_autor(
    p_nume_client in client.nume_client%type,
    p_prenume_client in client.prenume_client%type,
    p_carte in carte.cod_carte%type,
    v_rezultat out varchar2
) return varchar2 is

    -- variabile pentru validari
    v_nr_clienti number;
    v_nr_carti number;

    -- exceptii personalizate
    e_client exception;
    e_carte exception;
    
    v_rezultat_temp varchar2(4000);     -- variabila pentru rezultat
    v_nr_recenzii number;               -- variabila pentru numarul de exceptii

    -- tabela log
    pragma autonomous_transaction;

begin
    -- validare parametri de intrare
    if p_nume_client is null or p_prenume_client is null then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Parametrii de intrare sunt invalizi', 8, systimestamp);
        commit;
        return 'Parametrii de intrare sunt invalizi.';
    end if;

    -- verificare existenta client
    select count(*)
    into v_nr_clienti
    from client
    where lower(nume_client) = lower(p_nume_client)
      and lower(prenume_client) = lower(p_prenume_client);
       
    if v_nr_clienti = 0 then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Client inexistent: ' || p_nume_client || ' ' || p_prenume_client, 8, systimestamp);
        commit;
        raise e_client;
    end if;
    
    -- verificare existenta carte
    select count(*)
    into v_nr_carti
    from carte
    where p_carte = cod_carte;
    
    if v_nr_carti = 0 then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Carte inexistenta cu codul: ' || p_carte, 8, systimestamp);
        commit;
        raise e_carte;
    end if;

    -- verificare daca exista mai multe recenzii
    select count(*)
    into v_nr_recenzii
    from client cl
    join recenzie r on cl.id_client = r.id_client
    join carte c on r.cod_carte = c.cod_carte
    where lower(cl.nume_client) = lower(p_nume_client)
      and lower(cl.prenume_client) = lower(p_prenume_client)
      and p_carte = c.cod_carte;

    if v_nr_recenzii > 1 then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Exista ' || v_nr_recenzii || ' recenzii pentru acest client si carte.', 8, systimestamp);
        commit;
        raise too_many_rows;
    end if;

    -- obtinere rezultat unic
    select cl.nume_client || ' ' || cl.prenume_client || ' a lasat cartii "' ||
           c.nume_carte || '" nota ' || r.nota || ' si recenzia "' || r.descriere || '"'
    into v_rezultat_temp
    from client cl
    join recenzie r on cl.id_client = r.id_client
    join carte c on r.cod_carte = c.cod_carte
    where lower(cl.nume_client) = lower(p_nume_client) 
      and lower(cl.prenume_client) = lower(p_prenume_client)
      and p_carte = c.cod_carte;

    -- salvare rezultat in variabila out
    v_rezultat := v_rezultat_temp;
    return v_rezultat;

exception
    when no_data_found then
        v_rezultat := 'Clientul nu a lasat o recenzie pentru cartea specificata.';
        return v_rezultat;
        
    when e_client then
        v_rezultat := 'Clientul nu exista in baza de date.';
        return v_rezultat;
        
    when e_carte then
        v_rezultat := 'Cartea nu exista in baza de date.';
        return v_rezultat;
        
    when too_many_rows then
        v_rezultat := 'Eroare: exista mai multe inregistrari pentru criteriile specificate.';
        return v_rezultat;
        
    when others then
        -- logare erori neasteptate
        declare
            v_mesaj_log varchar2(4000);
        begin
            -- mesaj eroare
            v_mesaj_log := 'Eroare in procedura: ' || sqlerrm;

            -- insereaza in tabelul log_erori
            insert into log_erori (mesaj,nr_exercitiu, data_eroare)
            values (v_mesaj_log,8, systimestamp);
        
            commit;
        end;
        return 'Eroare neasteptata';
end obtine_carte_autor;
/

select* from log_erori;

declare
    rezultat varchar2(255);
begin
    dbms_output.put_line(obtine_carte_autor('ionescu','maria',100019,rezultat));
end;
/
;

---------------------------------------------------------------------------------------------------------------------------
--9. Formula?i în limbaj natural o problemã pe care sã o rezolva?i folosind un subprogram stocat independent de tip procedurã
--care sã aibã minim 2 parametri ?i sã utilizeze într-o singurã comandã SQL 5 dintre tabelele create. 
--Defini?i minim 2 excep?ii proprii, altele decât cele predefinite la nivel de sistem. 
--Apela?i subprogramul astfel încât sã eviden?ia?i toate cazurile definite ?i tratate.

create or replace procedure afiseaza_carti (
    p_gen in gen.nume_gen%type,
    p_nota_minima in number,
    p_rezultat out sys.odcivarchar2list -- colec?ie pentru rezultate
) is
    -- exceptii proprii
    e_gen exception; 
    e_nota exception;
    e_parametri exception;

    -- cursor pentru rezultate
    cursor_carti sys_refcursor;

    type varraygenuri is varray(10) of varchar2(50); -- vector pentru genuri
    genuri varraygenuri := varraygenuri();
    v_nota_maxima number;

    v_counter integer := 0; -- contor pentru validare rezultate
    v_exista_gen boolean := false;
    
    -- variabile pt cursor
    v_cc carte.cod_carte%type;
    v_nc carte.nume_carte%type;
    v_na autor.nume_autor%type;
    v_pa autor.prenume_autor%type;
    v_nt recenzie.nota%type;
    v_ne editura.nume_editura%type;
    v_ng gen.nume_gen%type;
    v_nl librarie.nume_librarie%type;

begin
    -- eroare parametri
    if p_gen is null or p_nota_minima is null then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Parametrii de intrare sunt invalizi.', 9, systimestamp);
        commit;
        raise e_parametri;
    end if;
    
    --  media maxima data
    select max(avg(nota))
    into v_nota_maxima
    from carte c, recenzie r
    where c.cod_carte=r.cod_carte
    group by c.cod_carte;
    
    if p_nota_minima > v_nota_maxima or p_nota_minima < 0 then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Nota nu se afla intre 0 si ' || v_nota_maxima || ' .', 9, systimestamp);
        commit;
        raise e_nota;
    end if;

    -- verificare daca genul dat ca parametru se afla in vectorul de genuri
    for gen in (
        select nume_gen as aux
        from gen g
    ) loop
        if genuri.count < genuri.limit then
            genuri.extend;
            genuri(genuri.count) := lower(gen.aux);
        end if;
    end loop;

    -- cauta daca genul este valid
    v_exista_gen := false;
    for i in 1..genuri.count loop
        if lower(genuri(i)) = lower(p_gen) then
            v_exista_gen := true;
            exit;
        end if;
    end loop;
    
    if not v_exista_gen then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Genul '||p_gen||' nu exista in baza de date.', 9, systimestamp);
        commit;
        raise e_gen;
    end if;

    -- deschide cursorul pentru date
    open cursor_carti for
        select c.cod_carte as cc,
               c.nume_carte as nc,
               a.nume_autor as na,
               a.prenume_autor as pa,
               e.nume_editura as ne,
               g.nume_gen as ng,
               l.nume_librarie as nl,
               avg(r.nota) as nt
        from carte c
        join autor a on c.cod_autor = a.cod_autor
        join editura e on c.cod_editura = e.cod_editura
        join librarie l on c.cod_librarie = l.cod_librarie
        join gen g on c.cod_gen = g.cod_gen
        join recenzie r on c.cod_carte = r.cod_carte
        where g.nume_gen = p_gen
        group by c.cod_carte, c.nume_carte, a.nume_autor, a.prenume_autor, e.nume_editura, g.nume_gen, l.nume_librarie
        having avg(r.nota) > p_nota_minima;
    p_rezultat := sys.odcivarchar2list();
    loop
        fetch cursor_carti into v_cc,v_nc,v_na,v_pa,v_ne,v_ng,v_nl,v_nt;
        exit when cursor_carti%notfound;
        v_counter := v_counter + 1;
        -- Adaugã fiecare carte la rezultatul final
        p_rezultat.extend;
        p_rezultat(p_rezultat.count) := 'Cartea: ' || v_nc || ' - codul: ' || v_cc || ' - autor: ' || v_na || ' ' || v_pa || ' - editura: ' || v_ne || ' - libraria: ' || v_nl || ' - nota: ' || v_nt;
    end loop;

    -- verificare daca exista rezultate
    if v_counter = 0 then
        insert into log_erori (mesaj, nr_exercitiu, data_eroare)
        values ('Nu exista carti care sa indeplineasca criteriile.', 9, systimestamp);
        commit;
        raise no_data_found;
    end if;

    close cursor_carti;

exception
    when e_parametri then
        raise_application_error(-20001, 'Parametrii nu pot fi nuli.');
    when e_nota then
        raise_application_error(-20002, 'Nota nu se afla intre 0 si ' || v_nota_maxima || ' .');
    when e_gen then
        raise_application_error(-20003, 'Genul '||p_gen||' nu exista in baza de date.');
    when no_data_found then
        raise_application_error(-20004, 'Eroare: nu exista carti care sa indeplineasca criteriile.');
    when others then
    declare
            v_mesaj_log varchar2(4000);
        begin
            -- mesaj eroare
            v_mesaj_log := 'Eroare in procedura: ' || sqlerrm;

            -- insereaza in tabelul log_erori
            insert into log_erori (mesaj,nr_exercitiu, data_eroare)
            values (v_mesaj_log, 6, systimestamp);
        
            commit;
        end;
        raise_application_error(-20005, 'Eroare neasteptata: ' || sqlerrm);
end afiseaza_carti;
/



select* from log_erori;

declare
    v_rezultat sys.odcivarchar2list;
begin
    afiseaza_carti('romance',10, v_rezultat);
    
    for i in 1..v_rezultat.count loop
        dbms_output.put_line(v_rezultat(i));
    end loop;
end;
/


-------------------------------------------------------------------------------------------
--10.Defini?i un trigger de tip LMD la nivel de comandã. Declan?a?i trigger-ul.

create or replace trigger trg_lmd_comanda
before insert on recenzie
declare
  mesaj varchar2(50);
  v_nume_tabela varchar2(50) := 'recenzie';
  v_nr_status number;
begin

    if inserting then
        mesaj := 'insert';
        dbms_output.put_line('S-a inserat in tabela recenzie.');
    elsif updating then
        mesaj := 'update';
        dbms_output.put_line('S-a modificat un rand in tabela recenzie.');
    elsif deleting then
        mesaj := 'delete';
        dbms_output.put_line('S-a sters un rand din tabela recenzie.');
    end if;
    
    insert into log_audit (nr_exercitiu, nume_tabela, mesaj, data_inregistrare)
    values (10, v_nume_tabela, mesaj, systimestamp);
end;
/

insert into recenzie (cod_recenzie, id_client, cod_carte, descriere, nota) values (19, 1012, 100000, 'Test', 5);
update recenzie set cod_recenzie=99 where cod_recenzie=19;
delete from recenzie where cod_recenzie=99;

select * from recenzie;
select * from log_audit;
commit;
-------------------------------------------------------------------------------------------------------------------------------------
--12.Defini?i un trigger de tip LDD. Declan?a?i trigger-ul.


select * from ldd_audit;

create or replace trigger trg_ldd
after create or alter or drop on database
declare
    v_nume_utilizator varchar2(50);
    v_tabela varchar2(100);
    v_tip_ldd varchar2(50);
begin
    v_nume_utilizator := sys_context('userenv', 'session_user');
    v_tabela := ora_dict_obj_name;
    v_tip_ldd := ora_sysevent;

    insert into ldd_audit (nr_exercitiu,nume_utilizator, tip_ldd, tabela, data_inregistrare)
    values (12,v_nume_utilizator, v_tip_ldd, v_tabela, systimestamp);

    if v_nume_utilizator not in ('SYSTEM') then
        raise_application_error(-20003, 'Operatii ldd neautorizate pentru utilizatorul ' || v_nume_utilizator);
    end if;

    dbms_output.put_line('Operatie ldd detectata: ' || v_tip_ldd || ' pe obiectul ' || v_tabela || ' de utilizatorul ' || v_nume_utilizator);
end;
/

----------------------------------------------------------------------------------------------------------------------------------
--11.Defini?i un trigger de tip LMD la nivel de linie. Declan?a?i trigger-ul.

-- tabela auxiliara pentru a nu avea mutating table
create table aux_carte_comanda as select * from carte_comanda;
drop table aux_carte_comanda;

create or replace trigger trg_lmd_linie
after insert or update or delete on carte_comanda
for each row
declare
    -- verificari
    v_exista_comanda number := 0;
    v_exista_carte number := 0;
    v_nr_comenzi number := 0;
    v_nr_librarii_in_comanda number := 0;
    v_count number := 0;
    v_client client.id_client%type;
    v_nume_status_comanda_noua status_comanda.nume_status_comanda%type;
    v_nume_status_comanda_veche status_comanda.nume_status_comanda%type;

    
    v_pret_carte_noua carte.pret_carte%type;
    v_pret_carte_veche carte.pret_carte%type;
    v_id_client client.id_client%type;
    v_cod_librarie_noua librarie.cod_librarie%type;
    v_cod_librarie_veche librarie.cod_librarie%type;
    
    -- exceptii
    e_comanda exception;
    e_carte exception;
    e_inregistrare exception;
    e_finalizata exception;
    
begin
    if inserting then
        -- verificare daca exista comanda
        select count(*)
        into v_exista_comanda
        from comanda
        where cod_comanda = :new.cod_comanda;
        
        if v_exista_comanda = 0 then
           raise e_comanda;
        end if;
        
        -- verificare daca exista cartea
        select count(*)
        into v_exista_carte
        from carte
        where cod_carte = :new.cod_carte;
        
        if v_exista_carte = 0 then
            raise e_carte;
        end if;
        
        select nume_status_comanda
        into v_nume_status_comanda_noua
        from status_comanda s,comanda c
        where c.cod_status = s.cod_status
        and c.cod_comanda = :new.cod_comanda;
        
        -- nu se pot adauga noi carti la o comanda finalizata
        if lower(v_nume_status_comanda_noua) != lower('finalizata') then 
            -- modificare pret total la comanda
            select pret_carte
            into v_pret_carte_noua
            from carte
            where cod_carte = :new.cod_carte;
            
            update comanda
            set pret_total = pret_total + v_pret_carte_noua
            where cod_comanda = :new.cod_comanda;
            
            -- inserare in detalii_comanda
            select cod_librarie
            into v_cod_librarie_noua
            from carte
            where cod_carte = :new.cod_carte;
            
            select count(*)
            into v_nr_librarii_in_comanda
            from detalii_comanda
            where cod_comanda = :new.cod_comanda
            and lower(cod_librarie) = lower(v_cod_librarie_noua);
            
            -- verificare daca in comanda exista deja libraria cartii noi
            if v_nr_librarii_in_comanda = 0 then
            
                select distinct id_client
                into v_id_client
                from detalii_comanda
                where cod_comanda = :new.cod_comanda;
                
                insert into detalii_comanda (cod_detalii_comanda, id_client, cod_librarie, cod_comanda)
                values (incrementare_detalii_comanda.nextval, v_id_client, v_cod_librarie_noua, :new.cod_comanda);
            
            end if;
            
            dbms_output.put_line('S-a adaugat o noua carte la comanda '||:new.cod_comanda);
        else
            raise e_finalizata;
        end if;
        
    elsif updating then
        -- verificare daca exista comanda
        select count(*)
        into v_exista_comanda
        from comanda
        where cod_comanda = :new.cod_comanda;
            
        if v_exista_comanda = 0 then
            raise e_comanda;
        end if;
        
        select nume_status_comanda
        into v_nume_status_comanda_noua
        from status_comanda s,comanda c
        where c.cod_status = s.cod_status
        and c.cod_comanda = :new.cod_comanda;
        
        select nume_status_comanda
        into v_nume_status_comanda_veche
        from status_comanda s,comanda c
        where c.cod_status = s.cod_status
        and c.cod_comanda = :old.cod_comanda;
        
        -- nu se pot schimba comenzile deja finalizate
        if lower(v_nume_status_comanda_noua) != lower('finalizata') 
            or lower(v_nume_status_comanda_veche) != lower('finalizata') then
            -- daca se schimba cartea
            if :old.cod_comanda = :new.cod_comanda then
                -- verificare daca exista cartea
                select count(*)
                into v_exista_carte
                from carte
                where cod_carte = :new.cod_carte;
            
                if v_exista_carte = 0 then
                    raise e_carte;
                end if;
                
                -- modificare pret la comanda
                select pret_carte
                into v_pret_carte_noua
                from carte
                where cod_carte = :new.cod_carte;
                
                select pret_carte
                into v_pret_carte_veche
                from carte
                where cod_carte = :old.cod_carte;
            
                update comanda
                set pret_total = pret_total - v_pret_carte_veche + v_pret_carte_noua
                where cod_comanda = :new.cod_comanda;
                
                -- modificare librarie
                select cod_librarie
                into v_cod_librarie_noua
                from carte
                where cod_carte = :new.cod_carte;
                
                select cod_librarie
                into v_cod_librarie_veche
                from carte
                where cod_carte = :old.cod_carte;
                
                select count(*)
                into v_nr_comenzi
                from detalii_comanda
                where cod_comanda = :new.cod_comanda;
                
                -- cazul in care sunt mai multe librarii la aceeasi comanda
                if v_nr_comenzi >=2 then
                    -- verific daca mai exista carti in comanda care au aceeasi librarie cu noua carte
                    select count(*)
                    into v_nr_librarii_in_comanda
                    from detalii_comanda
                    where cod_comanda = :new.cod_comanda
                    and lower(cod_librarie) = lower(v_cod_librarie_noua);
                   
                    -- daca libraria noua nu este asociata cu respectiva comanda, se adauga
                    if v_nr_librarii_in_comanda = 0 then
                   
                        select distinct id_client
                        into v_id_client
                        from detalii_comanda
                        where cod_comanda = :new.cod_comanda;
                    
                        insert into detalii_comanda (cod_detalii_comanda, id_client, cod_librarie, cod_comanda)
                            values (incrementare_detalii_comanda.nextval, v_id_client, v_cod_librarie_noua, :new.cod_comanda);
                        
                    end if;
                    

                    -- verific daca mai sunt carti in comanda cu aceeasi librarie ca libraria veche
                    select count(*)
                    into v_count
                    from aux_carte_comanda cc, carte c
                    where cod_comanda = :new.cod_comanda
                    and c.cod_carte = cc.cod_carte
                    and lower(cod_librarie) = lower(v_cod_librarie_veche);
                    
                    if v_count = 1 then
                        delete from detalii_comanda 
                        where cod_comanda = :new.cod_comanda
                        and lower(cod_librarie) = lower(v_cod_librarie_veche);
                    end if;
                    
                    
                elsif v_nr_comenzi = 1 and v_cod_librarie_noua != v_cod_librarie_veche then
                    update detalii_comanda
                    set cod_librarie = v_cod_librarie_noua
                    where cod_librarie = v_cod_librarie_veche
                    and cod_comanda = :new.cod_comanda;
            
                else
                    raise e_inregistrare;
                    
                end if;
                
               
            -- daca se schimba comanda
            else
                
                v_nr_comenzi := 0;
                
                -- numarul de carti de la comanda
                select count(cod_carte)
                into v_nr_comenzi
                from aux_carte_comanda cc, comanda c
                where c.cod_comanda = cc.cod_comanda
                and cc.cod_comanda = :old.cod_comanda;
                
                -- daca vechea comanda a avut doar o carte voi sterge inregistrarile respective din comanda si detalii_comanda
                if v_nr_comenzi = 1 then
                
                    delete from detalii_comanda
                    where cod_comanda = :old.cod_comanda;
                    
                    delete from comanda
                    where cod_comanda = :old.cod_comanda;
                    
                end if;
                
                select pret_carte
                into v_pret_carte_noua
                from carte
                where cod_carte = :new.cod_carte;
                
                -- adunare pret la totalul comenzii noi
                update comanda
                set pret_total = pret_total + v_pret_carte_noua
                where cod_comanda = :new.cod_comanda;
                
                -- scadere pret din totalul comenzii vechi
                update comanda
                set pret_total = pret_total - v_pret_carte_noua
                where cod_comanda = :old.cod_comanda;
                --------------------------------------------------------------
                -- modificare in tabela detalii_comanda
                -- adaugare
                select cod_librarie
                into v_cod_librarie_noua
                from carte
                where cod_carte = :new.cod_carte;
                
                -- daca nu mai exista o inregistrare in detalii_comanda cu libraria + comanda noua, o adaugam
                select count(*)
                into v_nr_librarii_in_comanda
                from detalii_comanda
                where cod_comanda = :new.cod_comanda
                and lower(cod_librarie) = lower(v_cod_librarie_noua);
            
                if v_nr_librarii_in_comanda = 0 then
                    select distinct id_client
                    into v_client
                    from detalii_comanda
                    where cod_comanda = :new.cod_comanda;
                
                    insert into detalii_comanda (cod_detalii_comanda, id_client, cod_librarie, cod_comanda)
                    values (incrementare_detalii_comanda.nextval, v_client, v_cod_librarie_noua, :new.cod_comanda);
                end if;
                
                -- stergere din detalii_comanda
                -- in cazul in care comanda veche are DOAR o carte din libraria cartii care a fost mutata la comanda noua, se va sterge inregistrarea
                -- daca sunt doua sau mai multe carti in aceeasi librarie nu se va sterge nimic
                select count(*)
                into v_nr_librarii_in_comanda
                from  aux_carte_comanda cc, carte c
                where c.cod_carte=cc.cod_carte
                and lower(c.cod_librarie) = lower(v_cod_librarie_noua)
                and cc.cod_comanda = :old.cod_comanda;
                
                if v_nr_librarii_in_comanda = 1 then
                
                    delete from detalii_comanda
                    where cod_comanda = :old.cod_comanda
                    and cod_librarie = v_cod_librarie_noua;
                    
                elsif v_nr_librarii_in_comanda = 0 then
                   raise e_inregistrare;
                end if;
                
                dbms_output.put_line('S-a modificat comanda '||:new.cod_comanda);
            end if;
        
        end if;

            
    elsif deleting then
    
        select nume_status_comanda
        into v_nume_status_comanda_veche
        from status_comanda s,comanda c
        where c.cod_status = s.cod_status
        and c.cod_comanda = :old.cod_comanda;
    
        if lower(v_nume_status_comanda_veche) != lower('finalizata') then
            
            -- modificare detalii_comanda
            
            select cod_librarie
            into v_cod_librarie_veche
            from carte
            where cod_carte = :old.cod_carte;
            
            select count(*)
            into v_nr_librarii_in_comanda
            from aux_carte_comanda cc, carte c
            where c.cod_carte=cc.cod_carte
            and lower(c.cod_librarie) = lower(v_cod_librarie_veche)
            and cc.cod_comanda = :old.cod_comanda;
            
            if v_nr_librarii_in_comanda = 1 then
            
                delete from detalii_comanda
                where cod_comanda = :old.cod_comanda
                and cod_librarie = v_cod_librarie_veche;
                
            elsif v_nr_librarii_in_comanda = 0 then
                raise e_inregistrare;
            end if;
            
            
            -- modificare comanda
            select count(cod_carte)
            into v_nr_comenzi
            from aux_carte_comanda cc, comanda c
            where c.cod_comanda = cc.cod_comanda
            and cc.cod_comanda = :old.cod_comanda;
                
            -- daca e doar o carte in comanda veche, stergem comanda
            if v_nr_comenzi = 1 then
            
                delete from detalii_comanda
                where cod_comanda = :old.cod_comanda;
                delete from comanda
                where cod_comanda = :old.cod_comanda;
    
            
            -- daca mai sunt carti pe langa cartea stearsa, scadem pretul
            elsif v_nr_comenzi > 1 then
                select pret_carte
                into v_pret_carte_veche
                from carte
                where cod_carte = :old.cod_carte;
                
                update comanda
                set pret_total = pret_total - v_pret_carte_veche
                where cod_comanda = :old.cod_comanda;
                
            else 
                    raise e_inregistrare;
            end if;
            
            dbms_output.put_line('S-a sters o carte din comanda '||:old.cod_comanda);
        else
            raise e_finalizata;         
        end if;    
        
    end if;
    
    

exception
    when e_inregistrare then
        raise_application_error(-20001, 'Nu exista inregistrare in tabele.');
    when e_carte then
        raise_application_error(-20002, 'Nu exista cartea in baza de date.');
    when e_comanda then
        raise_application_error(-20003, 'Nu exista comanda in baza de date.');
    when e_finalizata then
        raise_application_error(-20004, 'Nu se pot face modificari asupra comenzilor finalizate.');
    when others then
        raise_application_error(-20005, 'Eroare: ' || sqlerrm);
        
                
end;
/
set serveroutput on;
select * from log_erori;
select * from carte where cod_librarie like 'LAA';
select * from carte;
select * from carte_comanda order by 2;
select * from comanda;
select * from detalii_comanda order by 4;

select * from aux_carte_comanda;

-- nu exista comanda
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 0, 100001);
-- nu exista cartea
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 1, 1000);
-- se insereaza, se modifica pretul total la 34, se adauga in detalii_comanda
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 1, 100001);
-- se insereaza, se modifica pretul total la 44, nu se adauga nimic in detalii_comanda
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 6, 100012);
-- comanda finalizata
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 3, 100015);
update carte_comanda set cod_carte=100001 where cod_comanda=3 and cod_carte=100000;
delete from carte_comanda where cod_comanda = 10;
-- se da update, se modifica pretul din 38 in 30, nu se modifica in detalii_comanda
update carte_comanda set cod_carte = 100009 where cod_comanda = 8 and cod_carte = 100019;
-- se da update, se modifica pretul din 26 in 28, se sterge din detalii_comanda si nu se adauga nimic
update carte_comanda set cod_carte = 100021 where cod_comanda = 7 and cod_carte = 100003;
-- se da update, se modifica pretul din 20 in 16, se modifica in detalii_comanda
update carte_comanda set cod_carte = 100010 where cod_comanda = 6 and cod_carte = 100016;
-- se da update, se modifica pretul din in , se adauga in detalii_comanda
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 1, 100026);
update carte_comanda set cod_carte = 100019 where cod_carte = 100026 and cod_comanda = 1;
update carte_comanda set cod_carte = 100000 where cod_carte = 100019 and cod_comanda = 1;
delete from carte_comanda where cod_comanda = 1 and cod_carte = 100001;
-- se da update, se modifica preturile, se sterge de la 7 si se adauga la 6
update carte_comanda set cod_comanda = 6 where cod_comanda = 7 and cod_carte = 100010;
-- se modifica, se sterge comanda, se sterge de la 1 si se adauga la 2
update carte_comanda set cod_comanda = 2 where cod_comanda = 1;
-- se modifica, se modifica preturile la comenzile 1 si 2, nu se sterge de la 1 si se adauga la 2
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 1, 100008);
update carte_comanda set cod_comanda = 2 where cod_comanda = 1 and cod_carte= 100008;
delete from carte_comanda where cod_comanda = 1 and cod_carte = 100008;
-- se modifica, se schimba preturi, nu se modifica nimic in detalii_comanda
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 1, 100002);
insert into carte_comanda (cod_carte_comanda, cod_comanda, cod_carte) values (incrementare_carte_comanda.nextval, 1, 100020);
update carte_comanda set cod_comanda = 2 where cod_comanda = 1 and cod_carte = 100020;
-- stergere carte, comanda, detalii_comanda
delete from carte_comanda where cod_comanda = 1;

rollback;
commit;


------------------------------------------------------------------------------------------------------------------------
--13. Formula?i în limbaj natural o problemã pe care sã o rezolva?i folosind un pachet care sã includã tipuri de date complexe 
--?i obiecte necesare unui flux de ac?iuni integrate, specifice bazei de date definite (minim 2 tipuri de date, minim 2 func?ii, minim 2 proceduri).
select * from oras;

create or replace package gestionare_comenzi is

    type tip_adresa is record (
        cod_adresa adresa.cod_adresa%type,
        cod_oras oras.cod_oras%type,
        nume_oras oras.nume_oras%type,
        cod_strada strada.cod_strada%type,
        nume_strada strada.nume_strada%type,
        numar_strada strada.numar_strada%type
    );
    
    type tip_carti is table of varchar2(100);
    
    -- indexul e numele cartii iar valoarea este true sau false daca este sau nu cartea valabila
    type tip_carti_valabile is table of boolean index by varchar2(100);
    
    
    -- procedura pentru a obtine adresa de livrare pentru clientul care face comanda
    procedure obtine_adresa ( 
        f_nume in client.nume_client%type, 
        f_prenume in client.prenume_client%type, 
        f_nume_oras in oras.nume_oras%type,
        f_nume_strada in strada.nume_strada%type,
        f_numar_strada in strada.numar_strada%type,
        f_adresa out tip_adresa);
    
    -- procedura care adauga o noua inregistrare in tabela comanda
    procedure plasare_comanda ( 
        p_nume in client.nume_client%type, 
        p_prenume in client.prenume_client%type,
        p_nume_oras in oras.nume_oras%type,
        p_nume_strada in strada.nume_strada%type,
        p_numar_strada in strada.numar_strada%type,
        p_carti in tip_carti);
    
    -- functie care verifica daca sunt valabile cartile din lista de carti care se va comanda
    function verificare_valabilitate ( 
        f_carti in tip_carti) return tip_carti_valabile;
    
    -- functie care adauga fiecare carte in comanda si returneaza daca mai vrea clientul sa adauge alte carti sau nu
    function adaugare_carti_la_comanda ( 
        f_cod_comanda in comanda.cod_comanda%type, 
        f_id_client in client.id_client%type,
        f_carti in tip_carti) return number;-- numarul de carti care s au adaugat
    
    -- procedura pentru afisarea noii comenzi
    procedure afisare_comanda ( 
        f_cod_comanda in comanda.cod_comanda%type,
        f_nume_client in client.nume_client%type,
        f_prenume_client in client.prenume_client%type,
        f_adresa in tip_adresa);
    
    -- procedura plasare_comanda va apela prima data functia obtine_adresa
    -- apoi apeleaza functia adaugare_carti_la_comanda pentru cartile pe care le vrea clientul. in interiorul acestei functii se apeleaza si functia verificare_valabilitate
    -- la final se apeleaza procedura afisare_comanda
    
end gestionare_comenzi;
/


drop sequence incrementare_oras;
create sequence incrementare_oras
start with 111
increment by 1;

create or replace package body gestionare_comenzi is

   
    procedure obtine_adresa ( 
        f_nume in client.nume_client%type, 
        f_prenume in client.prenume_client%type, 
        f_nume_oras in oras.nume_oras%type,
        f_nume_strada in strada.nume_strada%type,
        f_numar_strada in strada.numar_strada%type,
        f_adresa out tip_adresa) is
        
        v_cod_client client.id_client%type;
        v_adresa adresa.cod_adresa%type;
        v_cod_strada strada.cod_strada%type;
        v_cod_oras oras.cod_oras%type;
        v_cod_adresa adresa.cod_adresa%type;
        adresa_noua number := 0;
        
        e_client exception;
        begin
            
            begin 
                select id_client
                into v_cod_client
                from client
                where lower(nume_client) = lower(f_nume)
                and lower(prenume_client) = lower(f_prenume);
            
            exception
                when no_data_found then
                    insert into log_erori (mesaj, nr_exercitiu, data_eroare)
                    values ('Nu exista clientul in baza de date.', 13, systimestamp);
                    commit;
                    raise e_client;
            end;
    
    
            begin
                select a.cod_adresa, o.cod_oras, o.nume_oras, s.cod_strada, s.nume_strada, s.numar_strada
                into f_adresa
                from adresa a, oras o, strada s
                where a.cod_oras = o.cod_oras
                and o.cod_strada = s.cod_strada
                and lower(o.nume_oras) = lower(f_nume_oras)
                and lower(s.nume_strada) = lower(f_nume_strada)
                and s.numar_strada = f_numar_strada;
                
            exception
                when no_data_found then
                    
                    insert into strada (cod_strada, nume_strada, numar_strada) values (incrementare_strada.nextval, f_nume_strada, f_numar_strada)
                    returning cod_strada
                    into v_cod_strada;
                    
                    insert into oras (cod_oras, nume_oras, cod_strada) values (incrementare_oras.nextval, f_nume_oras, v_cod_strada)
                    returning cod_oras
                    into v_cod_oras;
                    
                    insert into adresa (cod_adresa, cod_oras) values (incrementare_adresa.nextval, v_cod_oras)
                    returning cod_adresa
                    into v_cod_adresa;
            
                    insert into adresa_client (cod_adresa_client, cod_adresa, id_client) values (incrementare_adresa_client.nextval, v_cod_adresa, v_cod_client);
                    adresa_noua := 1;
            end;
            
            if adresa_noua = 1 then
                select a.cod_adresa, o.cod_oras, o.nume_oras, s.cod_strada, s.nume_strada, s.numar_strada
                into f_adresa
                from adresa a, oras o, strada s
                where a.cod_oras = o.cod_oras
                and o.cod_strada = s.cod_strada
                and lower(o.nume_oras) = lower(f_nume_oras)
                and lower(s.nume_strada) = lower(f_nume_strada)
                and s.numar_strada = f_numar_strada;
            end if;
            
            
        exception
            when e_client then
                raise_application_error(-20001, 'Nu exista clientul in baza de date.');
            when others then
                raise_application_error(-20002, 'Eroare neasteptata: '||sqlerrm);
        
        end obtine_adresa;
    
    
    function verificare_valabilitate ( 
        f_carti in tip_carti) return tip_carti_valabile is
        
        f_valabilitate_carti tip_carti_valabile;
        exista_carte number;
        aux_carte varchar2(100);
        
        begin
            
            for i in f_carti.first..f_carti.last loop
                aux_carte := f_carti(i);
                
                if aux_carte is not null then
                
                    -- verific daca respectiva carte se afla sau nu in baza de date
                    select count(*)
                    into exista_carte
                    from carte
                    where lower(trim(nume_carte)) = lower(trim(aux_carte));
                    
                    if exista_carte > 0 then
                        f_valabilitate_carti(aux_carte) := true;
                    else
                        f_valabilitate_carti(aux_carte) := false;
                    end if;
                end if;
            end loop;
            return f_valabilitate_carti;
        end verificare_valabilitate;
        
        
    function adaugare_carti_la_comanda ( 
        f_cod_comanda in comanda.cod_comanda%type, 
        f_id_client in client.id_client%type,
        f_carti in tip_carti) return number is
            
        aux_carte varchar2(100);
        f_valabilitate_carti tip_carti_valabile;
        v_cod_carte carte.cod_carte%type;
        aux number := 0;
        librarie_carte librarie.cod_librarie%type;
        f_nr_carti number;
            
        e_carti exception;
            
        begin
                
                if f_carti.count = 0 then
                    insert into log_erori (mesaj, nr_exercitiu, data_eroare)
                    values ('Lista de carti pentru comanda nu poate fi null.', 13, systimestamp);
                    commit;
                    raise e_carti;
                end if;
                
                f_valabilitate_carti := gestionare_comenzi.verificare_valabilitate(f_carti);
                
                f_nr_carti := 0;
                aux_carte := f_valabilitate_carti.first;
                
                while aux_carte is not null loop
                
                    if f_valabilitate_carti(aux_carte) then
                        f_nr_carti := f_nr_carti + 1;
                        
                        select cod_carte
                        into v_cod_carte
                        from carte
                        where lower(trim(nume_carte)) = lower(trim(aux_carte));
                        
                        -- sa se adauge in detalii_comanda prima inregistrare pentru noua comanda
                        -- restul se fac automat
                        if aux = 0 then
                            select cod_librarie
                            into librarie_carte
                            from carte
                            where lower(trim(nume_carte)) = lower(trim(aux_carte));
                            
                            insert into detalii_comanda (cod_detalii_comanda,cod_comanda, id_client, cod_librarie)
                            values (incrementare_detalii_comanda.nextval,f_cod_comanda, f_id_client, librarie_carte);
                            
                            aux := 1;
                        end if;
                        
                        insert into carte_comanda(cod_carte_comanda, cod_carte, cod_comanda)
                        values (incrementare_carte_comanda.nextval, v_cod_carte, f_cod_comanda);
                    
                    else
                        dbms_output.put_line('Cartea '||aux_carte||' nu este valabila.');
                    end if;
                    
                    aux_carte := f_valabilitate_carti.next(aux_carte);
                    
                end loop;
                
                return f_nr_carti;
                
        exception
            when e_carti then
                dbms_output.put_line('Eroare neasteptata: '||sqlerrm);
                return -1;
            when others then
                dbms_output.put_line('Eroare neasteptata: '||sqlerrm);
                return -2;
        end adaugare_carti_la_comanda;
                

    procedure afisare_comanda ( 
        f_cod_comanda in comanda.cod_comanda%type,
        f_nume_client in client.nume_client%type,
        f_prenume_client in client.prenume_client%type,
        f_adresa in tip_adresa) is
        
        cursor_carti sys_refcursor;
        v_nume_carte carte.nume_carte%type;
        v_nume_autor autor.nume_autor%type;
        v_prenume_autor autor.prenume_autor%type;
        v_nume_editura editura.nume_editura%type;
        v_nume_librarie librarie.nume_librarie%type;
        v_metoda_livrare metoda_livrare.firma_transport%type;
        
        begin
            
            dbms_output.put_line('Comanda '||f_cod_comanda);
            dbms_output.put_line('  Client: '||initcap(f_nume_client)||' '||initcap(f_prenume_client));
            dbms_output.put_line('  Carti:');
            
            open cursor_carti for
                'select nume_carte, nume_autor, prenume_autor, nume_editura, nume_librarie
                from carte c, autor a, editura e, librarie l, carte_comanda cc
                where c.cod_autor = a.cod_autor
                and c.cod_editura = e.cod_editura
                and c.cod_librarie = l.cod_librarie
                and cc.cod_carte = c.cod_carte
                and cc.cod_comanda = :1'
            using f_cod_comanda;
            
            loop
                fetch cursor_carti into v_nume_carte, v_nume_autor, v_prenume_autor, v_nume_editura, v_nume_librarie;
                exit when cursor_carti%notfound;
                
                dbms_output.put_line('      '||v_nume_carte||' - '||v_nume_autor||' '||v_prenume_autor||', editura: '||v_nume_editura||', libraria: '||v_nume_librarie);
            end loop;
            
            select firma_transport
            into v_metoda_livrare
            from metoda_livrare m, comanda c
            where c.cod_livrare = m.cod_livrare
            and c.cod_comanda = f_cod_comanda;
            
            dbms_output.put_line('  Firma livrare: '||v_metoda_livrare);
            
            dbms_output.put_line('  Adresa livrare: '||f_adresa.nume_oras||' '||f_adresa.nume_strada||' '||f_adresa.numar_strada);
        
        end afisare_comanda;
        
        
    procedure plasare_comanda ( 
        p_nume in client.nume_client%type, 
        p_prenume in client.prenume_client%type,
        p_nume_oras in oras.nume_oras%type,
        p_nume_strada in strada.nume_strada%type,
        p_numar_strada in strada.numar_strada%type,
        p_carti in tip_carti) is
        
        f_adresa tip_adresa;
        v_nr_random number;
        nr_carti number;
        v_cod_comanda comanda.cod_comanda%type;
        v_cod_client client.id_client%type;
        
        e_valabilitate exception;
        e_lista_nula exception;
        e_others exception;
        
        begin
            
            gestionare_comenzi.obtine_adresa(p_nume, p_prenume, p_nume_oras, p_nume_strada, p_numar_strada, f_adresa);
            
            v_nr_random := floor(dbms_random.value(1,8));
            
            insert into comanda (cod_comanda, pret_total, cod_adresa, cod_status, cod_livrare, data_plasare_comanda, finalizare_comanda)
            values (incrementare_comanda.nextval, 0, f_adresa.cod_adresa, 1, v_nr_random, to_char(sysdate,'dd-mm-yyyy'),null)
            returning cod_comanda
            into v_cod_comanda;
            
            select id_client
            into v_cod_client
            from client
            where lower(nume_client) = lower(p_nume)
            and lower(prenume_client) = lower(p_prenume);
            
            nr_carti := gestionare_comenzi.adaugare_carti_la_comanda(v_cod_comanda, v_cod_client, p_carti);
            
            if nr_carti = 0 then
                delete from comanda where cod_comanda = v_cod_comanda;
                raise e_valabilitate;
                
            elsif nr_carti = -1 then
                raise e_lista_nula;
                
            elsif nr_carti = -2 then
                raise e_others;
            end if;
            
            gestionare_comenzi.afisare_comanda(v_cod_comanda, p_nume, p_prenume, f_adresa);
            
        exception
            when e_valabilitate then
                delete from comanda where cod_comanda = v_cod_comanda;
                commit;
                raise_application_error(-20010, 'Nicio carte nu este valabila.');
            when e_lista_nula then
                delete from comanda where cod_comanda = v_cod_comanda;
                commit;
                raise_application_error(-20011, 'Lista cartilor nu poate fi null.');
            when e_others then
                delete from comanda where cod_comanda = v_cod_comanda;
                commit;
                raise_application_error(-20012, 'Eroare neasteptata la adaugarea cartilor: '||sqlerrm);
            when too_many_rows then
                raise_application_error(-20013, 'Se returneaza mai multe linii decat s-au cerut.');
            when others then
                raise_application_error(-20014, 'Eroare neasteptata: '||sqlerrm);
        end plasare_comanda;
        
end gestionare_comenzi;
/
                
                
DECLARE
    p_carti gestionare_comenzi.tip_carti := gestionare_comenzi.tip_carti('bla','nu eixista');
BEGIN
    gestionare_comenzi.plasare_comanda(
        p_nume => 'Popescu',
        p_prenume => 'Ion',
        p_nume_oras => 'Bucuresti',
        p_nume_strada => 'Mihai Eminescu',
        p_numar_strada => 10,
        p_carti => p_carti
    );

    DBMS_OUTPUT.PUT_LINE('Comanda plasata cu succes.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Eroare: ' || SQLERRM);
END;
/


rollback;               
         
                
              
    
    